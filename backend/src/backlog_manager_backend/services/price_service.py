import asyncio
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation

import httpx
import structlog
from cryptography.fernet import InvalidToken
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.encryption import decrypt
from backlog_manager_backend.config import settings
from backlog_manager_backend.integrations.discord import (
    is_valid_discord_webhook_url,
    send_discord_webhook_message,
)
from backlog_manager_backend.integrations.ggdeals import get_prices_by_steam_app_ids
from backlog_manager_backend.integrations.types import GgDealsGame
from backlog_manager_backend.repositories import (
    game_price_repo,
    user_game_price_alert_repo,
    user_repo,
)
from backlog_manager_backend.schemas.game_price import GamePrice, UpsertGamePriceParams
from backlog_manager_backend.schemas.user import User

logger = structlog.get_logger()

_STALE_AFTER_SECONDS = 3 * 60 * 60

_SWEEP_BATCH_SIZE = 25
_SWEEP_BATCH_PAUSE_SECONDS = 20.0
"""GG.deals allows 100 records per minute and 1000 per hour for one key and
counts every id of a request: 25 ids every 20 seconds is 75 a minute."""

_RATE_LIMIT_RETRIES = 2
_RATE_LIMIT_DEFAULT_WAIT_SECONDS = 60.0
_RATE_LIMIT_MAX_WAIT_SECONDS = 120.0
_KEY_REJECTED_STATUSES = (401, 403)
_INVALID_PRICE = "GG.deals API returned an invalid price"


class PriceSourceNotConfiguredError(Exception):
    """No GG.deals API key is configured for the user or the server, and
    there is no earlier answer to serve."""


class _SweepAbortedError(Exception):
    """The sweep cannot go on: the rate limit persisted after the retries
    of one batch, or GG.deals rejected the key."""


async def _sleep(seconds: float) -> None:
    await asyncio.sleep(seconds)


def _retry_after_seconds(response: httpx.Response) -> float:
    """How long to wait after a 429: GG.deals' Retry-After (in seconds) when
    it sends one, otherwise a default, capped so a bad header cannot stall
    the sweep."""
    try:
        wait = float(response.headers["Retry-After"])
    except (KeyError, ValueError):
        wait = _RATE_LIMIT_DEFAULT_WAIT_SECONDS
    return min(max(wait, 1.0), _RATE_LIMIT_MAX_WAIT_SECONDS)


def _now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _is_stale(checked_at: datetime) -> bool:
    return (_now() - checked_at).total_seconds() > _STALE_AFTER_SECONDS


def _decimal(value: str | None) -> Decimal | None:
    """A price from GG.deals as a number; anything that is not a finite
    number is a bad answer (httpx.DecodingError), like an unreadable body."""
    if value is None:
        return None
    try:
        parsed = Decimal(value)
    except InvalidOperation as error:
        raise httpx.DecodingError(_INVALID_PRICE) from error
    if not parsed.is_finite():
        raise httpx.DecodingError(_INVALID_PRICE)
    return parsed


async def _fetch_and_store_prices(
    session: AsyncSession, steam_app_ids: list[int], api_key: str
) -> dict[int, GamePrice]:
    """Refreshes the given games from GG.deals and persists them in one go.
    A game GG.deals does not know is stored without prices, so it is not
    asked for again before the cache runs out."""
    games: dict[int, GgDealsGame | None] = await get_prices_by_steam_app_ids(steam_app_ids, api_key)
    checked_at = _now()
    rows: list[UpsertGamePriceParams] = []
    for steam_app_id, game in games.items():
        prices = game.prices if game is not None else None
        rows.append(
            UpsertGamePriceParams(
                steam_app_id=steam_app_id,
                checked_at=checked_at,
                currency=prices.currency if prices else None,
                current_retail=_decimal(prices.current_retail) if prices else None,
                current_keyshops=_decimal(prices.current_keyshops) if prices else None,
                historical_retail=_decimal(prices.historical_retail) if prices else None,
                historical_keyshops=_decimal(prices.historical_keyshops) if prices else None,
                url=game.url if game else None,
            )
        )
    return {row.steam_app_id: await game_price_repo.upsert_game_price(session, row) for row in rows}


async def get_price_info(
    session: AsyncSession, steam_app_id: int, api_key: str | None
) -> GamePrice:
    """On-demand path behind GET /api/games/{id}/price: serves the persisted
    row unless it is missing or older than _STALE_AFTER_SECONDS, in which
    case it asks GG.deals with [api_key] (the user's own key or the
    server's). When GG.deals cannot be asked (no key) or fails, an older
    row is still better than nothing and is served; without one this
    raises PriceSourceNotConfiguredError or the httpx error."""
    existing = await game_price_repo.get_game_price(session, steam_app_id)
    if existing is not None and not _is_stale(existing.checked_at):
        return existing
    if not api_key:
        if existing is not None:
            return existing
        raise PriceSourceNotConfiguredError
    try:
        return (await _fetch_and_store_prices(session, [steam_app_id], api_key))[steam_app_id]
    except httpx.HTTPError:
        if existing is not None:
            return existing
        raise


def _lowest_ever_price(price: GamePrice) -> tuple[Decimal, str] | None:
    """The price (and where: "official store" or "keyshop") that is at the
    lowest it has ever been, the cheaper one when both are; None when
    neither is. A price of 0 is never one (a free game is always at its
    lowest)."""
    candidates = [
        (current, channel)
        for current, historical, channel in (
            (price.current_retail, price.historical_retail, "official store"),
            (price.current_keyshops, price.historical_keyshops, "keyshop"),
        )
        if current is not None and historical is not None and 0 < current <= historical
    ]
    return min(candidates, key=lambda candidate: candidate[0]) if candidates else None


def _format_alert_message(
    title: str, amount: Decimal, currency: str | None, channel: str, url: str | None
) -> str:
    price = f"{amount:.2f} {currency}" if currency else f"{amount:.2f}"
    message = f"🔥 **{title}** is at its lowest price ever: {price} ({channel})"
    return f"{message} - {url}" if url else message


def _resolve_discord_webhook_url(user: User) -> str | None:
    """Per-user-webhook-with-global-fallback, mirroring
    routes/games.py::_resolve_steamgriddb_api_key - except a per-user
    webhook that fails to decrypt, or either webhook failing Discord's
    URL format, returns None outright rather than falling back to the
    server-wide webhook: falling back there would send this user's sale
    details to a recipient they never configured."""
    if user.discord_webhook_url_encrypted and settings.steam_api_key_encryption_key:
        try:
            webhook_url = decrypt(
                user.discord_webhook_url_encrypted, settings.steam_api_key_encryption_key
            )
        except (InvalidToken, ValueError):
            logger.error("Failed to decrypt user's Discord webhook URL", user_id=user.id)
            return None
        if not is_valid_discord_webhook_url(webhook_url):
            logger.error("User's Discord webhook URL failed validation", user_id=user.id)
            return None
        return webhook_url
    if settings.discord_webhook_url and not is_valid_discord_webhook_url(
        settings.discord_webhook_url
    ):
        logger.error("Configured DISCORD_WEBHOOK_URL failed validation")
        return None
    return settings.discord_webhook_url


async def _refresh_batch_for_sweep(
    session: AsyncSession, steam_app_ids: list[int], api_key: str
) -> dict[int, GamePrice]:
    """Refreshes one batch, waiting out a 429 up to _RATE_LIMIT_RETRIES times
    before giving up with _SweepAbortedError; a rejected key aborts at once."""
    for attempt in range(_RATE_LIMIT_RETRIES + 1):
        try:
            return await _fetch_and_store_prices(session, steam_app_ids, api_key)
        except httpx.HTTPStatusError as error:
            status = error.response.status_code
            if status in _KEY_REJECTED_STATUSES:
                logger.error("GG.deals rejected the API key", status=status)
                raise _SweepAbortedError from error
            if status != 429:
                raise
            if attempt == _RATE_LIMIT_RETRIES:
                raise _SweepAbortedError from error
            await _sleep(_retry_after_seconds(error.response))
    raise AssertionError("unreachable")


async def check_prices_and_alert(session: AsyncSession) -> int:
    """The periodic sweep behind POST /api/prices/check: refreshes every
    tracked-but-not-yet-owned Steam App ID once with the server's GG.deals
    key (nothing happens without one), in batches with a pause that keeps
    to the rate limit, then sends one Discord message per (user, game)
    pair whose price is at its lowest ever - see docs/PRICE_TRACKING.md.
    Dedup (UserGamePriceAlert) and the webhook to notify are both per
    user, since two users tracking the same game may have different
    webhooks (their own, or the global fallback) and must each be
    notified independently.

    Alert-dedup is claimed atomically (try_claim_alert) before sending,
    so two overlapping sweeps can't both deliver the same alert; a
    failed send reverts the claim so a later sweep retries instead of
    the price going permanently unalerted."""
    api_key = settings.ggdeals_api_key
    if not api_key:
        logger.warning("Price sweep skipped: GGDEALS_API_KEY is not set")
        return 0

    alerts_sent = 0
    pairs = await game_price_repo.get_tracked_user_steam_app_id_pairs(session, owned=False)

    steam_app_ids = {steam_app_id for _, steam_app_id in pairs}
    checked_at = await game_price_repo.get_checked_at_by_steam_app_id(session, steam_app_ids)
    ordered = sorted(
        steam_app_ids,
        key=lambda steam_app_id: (
            steam_app_id in checked_at,
            checked_at.get(steam_app_id, _now()),
            steam_app_id,
        ),
    )

    prices: dict[int, GamePrice] = {}
    failed = 0
    aborted = False
    for start in range(0, len(ordered), _SWEEP_BATCH_SIZE):
        batch = ordered[start : start + _SWEEP_BATCH_SIZE]
        if start:
            await _sleep(_SWEEP_BATCH_PAUSE_SECONDS)
        try:
            prices.update(await _refresh_batch_for_sweep(session, batch, api_key))
        except _SweepAbortedError:
            aborted = True
            break
        except httpx.HTTPError:
            failed += len(batch)
            logger.error("Failed to refresh prices for sweep", games=len(batch))
    logger.info(
        "Price sweep refreshed",
        refreshed=len(prices),
        failed=failed,
        skipped=len(ordered) - len(prices) - failed if aborted else 0,
    )

    for user_id, steam_app_id in pairs:
        price = prices.get(steam_app_id)
        lowest = _lowest_ever_price(price) if price is not None else None
        if price is None or lowest is None:
            continue
        amount, channel = lowest

        user = await user_repo.get_user_by_id(session, user_id)
        webhook_url = _resolve_discord_webhook_url(user)
        if webhook_url is None:
            continue

        claimed = await user_game_price_alert_repo.try_claim_alert(
            session, user_id, steam_app_id, amount
        )
        if not claimed:
            continue

        title = await game_price_repo.get_title_for_user_steam_app_id(
            session, user_id, steam_app_id
        )
        delivered = await send_discord_webhook_message(
            webhook_url,
            _format_alert_message(
                title or f"Steam App {steam_app_id}", amount, price.currency, channel, price.url
            ),
        )
        if not delivered:
            await user_game_price_alert_repo.clear_last_alerted_price(
                session, user_id, steam_app_id
            )
            continue
        alerts_sent += 1
    return alerts_sent

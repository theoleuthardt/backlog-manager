from datetime import UTC, date, datetime
from decimal import Decimal

import httpx
import structlog
from cryptography.fernet import InvalidToken
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.encryption import decrypt
from backlog_manager_backend.config import settings
from backlog_manager_backend.integrations.cheapshark import (
    find_cheapshark_game_id,
    get_cheapshark_game_detail,
    get_stores,
)
from backlog_manager_backend.integrations.discord import send_discord_webhook_message
from backlog_manager_backend.repositories import (
    game_price_repo,
    user_game_price_alert_repo,
    user_repo,
)
from backlog_manager_backend.schemas.game_price import GamePrice, UpsertGamePriceParams
from backlog_manager_backend.schemas.user import User

logger = structlog.get_logger()

_STALE_AFTER_SECONDS = 60 * 60

# storeID -> storeName, unbounded and never expired like game_service's
# _genre_cache/_platform_cache - CheapShark's store list changes rarely.
_store_names: dict[str, str] = {}
# storeID -> full icon URL, populated alongside _store_names below.
_store_icons: dict[str, str] = {}

_DEAL_REDIRECT_URL = "https://www.cheapshark.com/redirect?dealID="
_STORE_ICON_BASE_URL = "https://www.cheapshark.com"


def _now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _is_stale(checked_at: datetime) -> bool:
    return (_now() - checked_at).total_seconds() > _STALE_AFTER_SECONDS


async def _ensure_stores_cached() -> None:
    if _store_names:
        return
    try:
        for store in await get_stores():
            _store_names[store.storeID] = store.storeName
            _store_icons[store.storeID] = f"{_STORE_ICON_BASE_URL}{store.images.icon}"
    except httpx.HTTPError:
        logger.error("Failed to fetch CheapShark store list")


def _cheapest_price_ever_date(timestamp: int) -> date | None:
    return datetime.fromtimestamp(timestamp, tz=UTC).date() if timestamp else None


async def _fetch_and_store_price(session: AsyncSession, steam_app_id: int) -> GamePrice:
    """Refreshes one game's price data from CheapShark and persists it."""
    await _ensure_stores_cached()

    cheapshark_game_id = await find_cheapshark_game_id(steam_app_id)
    if cheapshark_game_id is None:
        return await game_price_repo.upsert_game_price(
            session,
            UpsertGamePriceParams(
                steam_app_id=steam_app_id, deals=[], on_sale=False, checked_at=_now()
            ),
        )

    detail = await get_cheapshark_game_detail(cheapshark_game_id)
    deals = [
        {
            "store": _store_names.get(deal.storeID, deal.storeID),
            "icon": _store_icons.get(deal.storeID, ""),
            "price": float(deal.price),
            "retail_price": float(deal.retailPrice),
            "url": f"{_DEAL_REDIRECT_URL}{deal.dealID}",
        }
        for deal in detail.deals
    ]
    on_sale = any(float(deal.savings) > 0 for deal in detail.deals)
    cheapest_price_ever = (
        Decimal(detail.cheapestPriceEver.price) if detail.cheapestPriceEver.price else None
    )

    return await game_price_repo.upsert_game_price(
        session,
        UpsertGamePriceParams(
            steam_app_id=steam_app_id,
            deals=deals,
            on_sale=on_sale,
            checked_at=_now(),
            cheapshark_game_id=cheapshark_game_id,
            cheapest_price_ever=cheapest_price_ever,
            cheapest_price_ever_date=_cheapest_price_ever_date(detail.cheapestPriceEver.date),
        ),
    )


async def get_price_info(session: AsyncSession, steam_app_id: int) -> GamePrice:
    """On-demand path powering the BacklogEntry detail view - serves the
    persisted GamePrice row unless it's missing or older than
    _STALE_AFTER_SECONDS, in which case it refreshes from CheapShark
    first."""
    existing = await game_price_repo.get_game_price(session, steam_app_id)
    if existing is not None and not _is_stale(existing.checked_at):
        return existing
    return await _fetch_and_store_price(session, steam_app_id)


def _format_alert_message(title: str, price: float, store: str, retail_price: float) -> str:
    return (
        f"🔥 **{title}** is on sale for ${price:.2f} at {store} "
        f"(was ${retail_price:.2f})!"
    )


def _resolve_discord_webhook_url(user: User) -> str | None:
    """Per-user-webhook-with-global-fallback, mirroring
    routes/games.py::_resolve_steamgriddb_api_key - a missing/undecryptable
    per-user webhook resolves to the global settings.discord_webhook_url
    fallback (itself possibly None, meaning no alerts for this user)
    rather than raising, since a webhook is an optional feature."""
    if user.discord_webhook_url_encrypted and settings.steam_api_key_encryption_key:
        try:
            return decrypt(user.discord_webhook_url_encrypted, settings.steam_api_key_encryption_key)
        except (InvalidToken, ValueError):
            return settings.discord_webhook_url
    return settings.discord_webhook_url


async def check_prices_and_alert(session: AsyncSession) -> int:
    """The periodic sweep behind POST /api/prices/check: refreshes every
    tracked-but-not-yet-owned Steam App ID's price once, then sends one
    Discord message per (user, game) pair that is newly on sale for that
    user - see docs/PRICE_TRACKING.md. Dedup (UserGamePriceAlert) and the
    webhook to notify are both per user, since two users tracking the
    same game may have different webhooks (their own, or the global
    fallback) and must each be notified independently."""
    alerts_sent = 0
    pairs = await game_price_repo.get_tracked_user_steam_app_id_pairs(session, owned=False)

    prices: dict[int, GamePrice] = {}
    for steam_app_id in {steam_app_id for _, steam_app_id in pairs}:
        try:
            prices[steam_app_id] = await _fetch_and_store_price(session, steam_app_id)
        except httpx.HTTPError:
            logger.error("Failed to refresh price for sweep", steam_app_id=steam_app_id)

    for user_id, steam_app_id in pairs:
        price = prices.get(steam_app_id)
        if price is None or not price.on_sale or not price.deals:
            continue

        user = await user_repo.get_user_by_id(session, user_id)
        webhook_url = _resolve_discord_webhook_url(user)
        if webhook_url is None:
            continue

        cheapest_deal = min(price.deals, key=lambda deal: deal["price"])
        current_price = cheapest_deal["price"]
        last_alerted = await user_game_price_alert_repo.get_last_alerted_price(
            session, user_id, steam_app_id
        )
        if last_alerted is not None and float(last_alerted) == current_price:
            continue

        title = await game_price_repo.get_title_for_steam_app_id(session, steam_app_id)
        await send_discord_webhook_message(
            webhook_url,
            _format_alert_message(
                title or f"Steam App {steam_app_id}",
                current_price,
                cheapest_deal["store"],
                cheapest_deal["retail_price"],
            ),
        )
        await user_game_price_alert_repo.set_last_alerted_price(
            session, user_id, steam_app_id, Decimal(str(current_price))
        )
        alerts_sent += 1
    return alerts_sent

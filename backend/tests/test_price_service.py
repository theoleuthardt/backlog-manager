from datetime import UTC, datetime, timedelta
from decimal import Decimal
from types import ModuleType

import httpx
import pytest
from cryptography.fernet import Fernet
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import GgDealsGame, GgDealsPrices
from backlog_manager_backend.models.user_game_price_alert import UserGamePriceAlert
from backlog_manager_backend.repositories import backlog_entry_repo, game_price_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.game_price import UpsertGamePriceParams
from backlog_manager_backend.schemas.user import CreateUserParams

_REAL_WEBHOOK_URL = "https://discord.com/api/webhooks/123456789012345678/token-abc"
_OTHER_REAL_WEBHOOK_URL = "https://discord.com/api/webhooks/987654321098765432/token-xyz"
_KEY = "server-key"


@pytest.fixture
def price_service(monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.services import price_service as module

    monkeypatch.setattr(settings, "ggdeals_api_key", _KEY)
    return module


def _game(
    *,
    retail: str | None = "9.99",
    keyshops: str | None = "4.50",
    historical_retail: str | None = "1.99",
    historical_keyshops: str | None = "1.50",
) -> GgDealsGame:
    return GgDealsGame(
        title="Half-Life 2",
        url="https://gg.deals/game/half-life-2/",
        prices=GgDealsPrices(
            currency="EUR",
            current_retail=retail,
            current_keyshops=keyshops,
            historical_retail=historical_retail,
            historical_keyshops=historical_keyshops,
        ),
    )


def _at_historical_low() -> GgDealsGame:
    return _game(retail="1.99", keyshops="2.50")


def _serve(
    price_service: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
    answers: dict[int, GgDealsGame | None] | None = None,
    game: GgDealsGame | None = None,
) -> list[list[int]]:
    """Replaces the GG.deals client: every id gets `game` unless `answers`
    says otherwise; returns the list of requested id batches."""
    batches: list[list[int]] = []

    async def fake_get(steam_app_ids: list[int], api_key: str) -> dict[int, GgDealsGame | None]:
        assert api_key == _KEY
        batches.append(list(steam_app_ids))
        if answers is not None:
            return {i: answers.get(i) for i in steam_app_ids}
        return dict.fromkeys(steam_app_ids, game)

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", fake_get)
    return batches


async def _make_user(session: AsyncSession, email: str = "priceowner@example.com") -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username=email.split("@")[0], email=email, password_hash="h"),
    )


async def _make_entry(
    session: AsyncSession, user_id: int, *, steam_app_id: int, owned: bool = False
) -> object:
    return await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user_id,
            title="Half-Life 2",
            genre="FPS",
            platform="PC",
            status="Not Started",
            owned=owned,
            interest=8,
            steam_app_id=steam_app_id,
        ),
    )


async def _last_alerted_price(
    session: AsyncSession, user_id: int, steam_app_id: int
) -> Decimal | None:
    model = await session.get(UserGamePriceAlert, (user_id, steam_app_id))
    return model.last_alerted_price if model is not None else None


async def _store(session: AsyncSession, steam_app_id: int, age: timedelta) -> None:
    await game_price_repo.upsert_game_price(
        session,
        UpsertGamePriceParams(
            steam_app_id=steam_app_id,
            checked_at=datetime.now(UTC).replace(tzinfo=None) - age,
            currency="EUR",
            current_retail=Decimal("5.00"),
        ),
    )


async def test_get_price_info_uses_a_fresh_cache_without_asking_gg_deals(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    await _store(session, 220, timedelta(minutes=10))
    batches = _serve(price_service, monkeypatch, game=_game())

    info = await price_service.get_price_info(session, 220, _KEY)

    assert info.current_retail == Decimal("5.00")
    assert batches == []


async def test_get_price_info_refreshes_a_stale_row(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    await _store(session, 220, timedelta(hours=4))
    _serve(price_service, monkeypatch, game=_game())

    info = await price_service.get_price_info(session, 220, _KEY)

    assert info.current_retail == Decimal("9.99")
    assert info.current_keyshops == Decimal("4.50")
    assert info.historical_retail == Decimal("1.99")
    assert info.historical_keyshops == Decimal("1.50")
    assert info.currency == "EUR"
    assert info.url == "https://gg.deals/game/half-life-2/"
    stored = await game_price_repo.get_game_price(session, 220)
    assert stored is not None
    assert stored.current_retail == Decimal("9.99")


async def test_get_price_info_remembers_a_game_gg_deals_does_not_know(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    batches = _serve(price_service, monkeypatch, answers={})

    first = await price_service.get_price_info(session, 999999, _KEY)
    second = await price_service.get_price_info(session, 999999, _KEY)

    assert first.current_retail is None
    assert first.url is None
    assert second.steam_app_id == 999999
    assert batches == [[999999]]


@pytest.mark.parametrize("no_key", [None, ""])
async def test_get_price_info_without_a_key_serves_a_stale_row_or_raises(
    no_key: str | None,
    price_service: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
    session: AsyncSession,
) -> None:
    await _store(session, 220, timedelta(hours=9))
    batches = _serve(price_service, monkeypatch, game=_game())

    stale = await price_service.get_price_info(session, 220, no_key)

    assert stale.current_retail == Decimal("5.00")
    with pytest.raises(price_service.PriceSourceNotConfiguredError):
        await price_service.get_price_info(session, 221, no_key)
    assert batches == []


@pytest.mark.parametrize("bad", ["N/A", "", "NaN", "Infinity"])
async def test_a_malformed_price_is_a_decoding_error_and_stores_nothing(
    bad: str, price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    _serve(
        price_service,
        monkeypatch,
        answers={220: _game(), 221: _game(retail=bad)},
    )

    async def ask() -> None:
        await price_service._fetch_and_store_prices(session, [220, 221], _KEY)

    with pytest.raises(httpx.DecodingError):
        await ask()
    assert await game_price_repo.get_game_price(session, 220) is None


async def test_the_sweep_goes_on_after_a_batch_with_a_malformed_price(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    size = price_service._SWEEP_BATCH_SIZE
    await _entries_for(session, list(range(1, size + 2)))
    _patch_sleep(price_service, monkeypatch)
    calls = 0

    async def fake_get(steam_app_ids: list[int], api_key: str) -> dict:
        nonlocal calls
        calls += 1
        bad = _game(retail="N/A") if calls == 1 else _game()
        return dict.fromkeys(steam_app_ids, bad)

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", fake_get)

    await price_service.check_prices_and_alert(session)

    assert calls == 2


@pytest.mark.parametrize("status", [429, 500])
async def test_get_price_info_serves_the_stale_row_when_gg_deals_fails(
    status: int, price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    await _store(session, 220, timedelta(hours=9))

    async def failing(steam_app_ids: list[int], api_key: str) -> dict:
        request = httpx.Request("GET", "https://api.gg.deals/v1/prices/by-steam-app-id/")
        raise httpx.HTTPStatusError(
            "error", request=request, response=httpx.Response(status, request=request)
        )

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", failing)

    info = await price_service.get_price_info(session, 220, _KEY)
    assert info.current_retail == Decimal("5.00")

    with pytest.raises(httpx.HTTPStatusError):
        await price_service.get_price_info(session, 555, _KEY)


async def test_the_sweep_alerts_when_a_price_is_at_its_historical_low(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)
    sent: list[tuple[str, str]] = []

    async def fake_send(webhook_url: str, content: str) -> bool:
        sent.append((webhook_url, content))
        return True

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _serve(price_service, monkeypatch, game=_at_historical_low())
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    alerts_sent = await price_service.check_prices_and_alert(session)

    assert alerts_sent == 1
    assert sent[0][0] == _REAL_WEBHOOK_URL
    assert "Half-Life 2" in sent[0][1]
    assert "1.99 EUR" in sent[0][1]
    assert "https://gg.deals/game/half-life-2/" in sent[0][1]
    assert await _last_alerted_price(session, user.id, 220) == Decimal("1.99")


async def test_the_sweep_alerts_for_a_keyshop_price_at_its_historical_low(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)
    sent: list[str] = []

    async def fake_send(webhook_url: str, content: str) -> bool:
        sent.append(content)
        return True

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _serve(price_service, monkeypatch, game=_game(retail="9.99", keyshops="1.50"))
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    assert await price_service.check_prices_and_alert(session) == 1
    assert "1.50 EUR" in sent[0]
    assert "keyshop" in sent[0]


@pytest.mark.parametrize(
    "game",
    [
        _game(),
        _game(retail=None, keyshops=None),
        _game(historical_retail=None, historical_keyshops=None),
        _game(retail="0.00", keyshops=None, historical_retail="0.00", historical_keyshops=None),
    ],
)
async def test_the_sweep_does_not_alert_without_a_historical_low(
    game: GgDealsGame,
    price_service: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
    session: AsyncSession,
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)

    async def fail_send(*args: object, **kwargs: object) -> None:
        raise AssertionError("no alert expected")

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _serve(price_service, monkeypatch, game=game)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fail_send)

    assert await price_service.check_prices_and_alert(session) == 0


async def test_the_sweep_skips_owned_games(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=True)
    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    batches = _serve(price_service, monkeypatch, game=_at_historical_low())

    assert await price_service.check_prices_and_alert(session) == 0
    assert batches == []


async def test_the_sweep_does_nothing_without_a_server_key(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)
    monkeypatch.setattr(settings, "ggdeals_api_key", None)
    batches = _serve(price_service, monkeypatch, game=_at_historical_low())

    assert await price_service.check_prices_and_alert(session) == 0
    assert batches == []


async def test_the_sweep_stores_prices_without_a_webhook(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)

    async def fail_send(*args: object, **kwargs: object) -> None:
        raise AssertionError("must not call Discord without a configured webhook")

    monkeypatch.setattr(settings, "discord_webhook_url", None)
    _serve(price_service, monkeypatch, game=_at_historical_low())
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fail_send)

    assert await price_service.check_prices_and_alert(session) == 0
    stored = await game_price_repo.get_game_price(session, 220)
    assert stored is not None
    assert stored.current_retail == Decimal("1.99")


async def test_the_sweep_does_not_repeat_the_same_price(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)
    sent: list[str] = []

    async def fake_send(webhook_url: str, content: str) -> bool:
        sent.append(content)
        return True

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _serve(price_service, monkeypatch, game=_at_historical_low())
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    await price_service.check_prices_and_alert(session)
    second = await price_service.check_prices_and_alert(session)

    assert second == 0
    assert len(sent) == 1


async def test_the_sweep_notifies_each_user_independently(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user1 = await _make_user(session, "priceowner1@example.com")
    await _make_entry(session, user1.id, steam_app_id=220, owned=False)
    sent: list[str] = []

    async def fake_send(webhook_url: str, content: str) -> bool:
        sent.append(webhook_url)
        return True

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _serve(price_service, monkeypatch, game=_at_historical_low())
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    assert await price_service.check_prices_and_alert(session) == 1

    user2 = await _make_user(session, "priceowner2@example.com")
    await _make_entry(session, user2.id, steam_app_id=220, owned=False)

    assert await price_service.check_prices_and_alert(session) == 1
    assert sent == [_REAL_WEBHOOK_URL, _REAL_WEBHOOK_URL]


async def test_the_sweep_reverts_the_dedup_when_delivery_fails(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)
    attempts: list[bool] = [False, True]

    async def flaky_send(webhook_url: str, content: str) -> bool:
        return attempts.pop(0)

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _serve(price_service, monkeypatch, game=_at_historical_low())
    monkeypatch.setattr(price_service, "send_discord_webhook_message", flaky_send)

    assert await price_service.check_prices_and_alert(session) == 0
    assert await _last_alerted_price(session, user.id, 220) is None
    assert await price_service.check_prices_and_alert(session) == 1
    assert await _last_alerted_price(session, user.id, 220) == Decimal("1.99")


async def test_resolve_discord_webhook_url_prefers_users_own_webhook(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.auth.encryption import encrypt
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.schemas.user import User

    encryption_key = Fernet.generate_key().decode()
    monkeypatch.setattr(settings, "steam_api_key_encryption_key", encryption_key)
    monkeypatch.setattr(settings, "discord_webhook_url", _OTHER_REAL_WEBHOOK_URL)

    user = User(
        id=1,
        name="alice",
        email="alice@example.com",
        created_at=datetime.now(UTC).replace(tzinfo=None),
        updated_at=datetime.now(UTC).replace(tzinfo=None),
        discord_webhook_url_encrypted=encrypt(_REAL_WEBHOOK_URL, encryption_key),
    )

    assert price_service._resolve_discord_webhook_url(user) == _REAL_WEBHOOK_URL


async def test_resolve_discord_webhook_url_returns_none_when_undecryptable(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A per-user webhook that fails to decrypt must not silently fall
    back to the server-wide webhook - that would send this user's sale
    details to a recipient they never configured."""
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.schemas.user import User

    monkeypatch.setattr(settings, "steam_api_key_encryption_key", Fernet.generate_key().decode())
    monkeypatch.setattr(settings, "discord_webhook_url", _OTHER_REAL_WEBHOOK_URL)

    user = User(
        id=1,
        name="alice",
        email="alice@example.com",
        created_at=datetime.now(UTC).replace(tzinfo=None),
        updated_at=datetime.now(UTC).replace(tzinfo=None),
        discord_webhook_url_encrypted="not-a-valid-fernet-token",
    )

    assert price_service._resolve_discord_webhook_url(user) is None


async def test_resolve_discord_webhook_url_returns_none_for_invalid_configured_fallback(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.schemas.user import User

    monkeypatch.setattr(settings, "discord_webhook_url", "http://internal.example/steal-alerts")

    user = User(
        id=1,
        name="alice",
        email="alice@example.com",
        created_at=datetime.now(UTC).replace(tzinfo=None),
        updated_at=datetime.now(UTC).replace(tzinfo=None),
    )

    assert price_service._resolve_discord_webhook_url(user) is None


def _status_error(status: int, retry_after: str | None = None) -> httpx.HTTPStatusError:
    headers = {"Retry-After": retry_after} if retry_after is not None else {}
    request = httpx.Request("GET", "https://api.gg.deals/v1/prices/by-steam-app-id/")
    response = httpx.Response(status, headers=headers, request=request)
    return httpx.HTTPStatusError(
        f"GG.deals API error: {status}", request=request, response=response
    )


async def _entries_for(session: AsyncSession, steam_app_ids: list[int]) -> None:
    user = await _make_user(session, "sweepowner@example.com")
    for steam_app_id in steam_app_ids:
        await _make_entry(session, user.id, steam_app_id=steam_app_id, owned=False)


def _patch_sleep(price_service: ModuleType, monkeypatch: pytest.MonkeyPatch) -> list[float]:
    sleeps: list[float] = []

    async def fake_sleep(seconds: float) -> None:
        sleeps.append(seconds)

    monkeypatch.setattr(price_service, "_sleep", fake_sleep)
    return sleeps


async def test_the_sweep_asks_in_batches_and_pauses_between_them(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    size = price_service._SWEEP_BATCH_SIZE
    ids = list(range(1, size * 2 + 2))
    await _entries_for(session, ids)
    sleeps = _patch_sleep(price_service, monkeypatch)
    batches = _serve(price_service, monkeypatch, game=_game())

    await price_service.check_prices_and_alert(session)

    assert [len(batch) for batch in batches] == [size, size, 1]
    assert sorted(i for batch in batches for i in batch) == ids
    assert sleeps == [price_service._SWEEP_BATCH_PAUSE_SECONDS] * 2


async def test_the_sweep_waits_out_a_rate_limit_and_asks_again(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    await _entries_for(session, [220])
    sleeps = _patch_sleep(price_service, monkeypatch)
    calls = 0

    async def fake_get(steam_app_ids: list[int], api_key: str) -> dict:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise _status_error(429, "7")
        return dict.fromkeys(steam_app_ids, _game())

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", fake_get)

    await price_service.check_prices_and_alert(session)

    assert sleeps == [7]
    assert await game_price_repo.get_game_price(session, 220) is not None


async def test_the_sweep_stops_when_the_rate_limit_persists(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    size = price_service._SWEEP_BATCH_SIZE
    await _entries_for(session, list(range(1, size * 2 + 1)))
    _patch_sleep(price_service, monkeypatch)
    calls = 0

    async def fake_get(steam_app_ids: list[int], api_key: str) -> dict:
        nonlocal calls
        calls += 1
        raise _status_error(429)

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", fake_get)

    await price_service.check_prices_and_alert(session)

    assert calls == price_service._RATE_LIMIT_RETRIES + 1


@pytest.mark.parametrize("status", [401, 403])
async def test_the_sweep_stops_when_the_key_is_rejected(
    status: int,
    price_service: ModuleType,
    monkeypatch: pytest.MonkeyPatch,
    session: AsyncSession,
) -> None:
    size = price_service._SWEEP_BATCH_SIZE
    await _entries_for(session, list(range(1, size * 2 + 1)))
    _patch_sleep(price_service, monkeypatch)
    calls = 0

    async def fake_get(steam_app_ids: list[int], api_key: str) -> dict:
        nonlocal calls
        calls += 1
        raise _status_error(status)

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", fake_get)

    await price_service.check_prices_and_alert(session)

    assert calls == 1


async def test_the_sweep_goes_on_after_a_failed_batch(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    size = price_service._SWEEP_BATCH_SIZE
    await _entries_for(session, list(range(1, size + 2)))
    _patch_sleep(price_service, monkeypatch)
    calls = 0

    async def fake_get(steam_app_ids: list[int], api_key: str) -> dict:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise _status_error(500)
        return dict.fromkeys(steam_app_ids, _game())

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", fake_get)

    await price_service.check_prices_and_alert(session)

    assert calls == 2


async def test_the_sweep_clamps_an_excessive_retry_after(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    await _entries_for(session, [220])
    sleeps = _patch_sleep(price_service, monkeypatch)
    calls = 0

    async def fake_get(steam_app_ids: list[int], api_key: str) -> dict:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise _status_error(429, "86400")
        return dict.fromkeys(steam_app_ids, _game())

    monkeypatch.setattr(price_service, "get_prices_by_steam_app_ids", fake_get)

    await price_service.check_prices_and_alert(session)

    assert sleeps == [price_service._RATE_LIMIT_MAX_WAIT_SECONDS]


async def test_the_sweep_refreshes_the_least_recently_checked_games_first(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    await _entries_for(session, [1, 2, 3])
    await _store(session, 1, timedelta(hours=1))
    await _store(session, 2, timedelta(hours=5))
    _patch_sleep(price_service, monkeypatch)
    batches = _serve(price_service, monkeypatch, game=_game())

    await price_service.check_prices_and_alert(session)

    assert batches == [[3, 2, 1]]

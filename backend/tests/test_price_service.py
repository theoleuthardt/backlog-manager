from datetime import UTC, datetime, timedelta
from decimal import Decimal
from types import ModuleType

import pytest
from cryptography.fernet import Fernet
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import (
    CheapSharkDeal,
    CheapSharkGameDetail,
    CheapSharkGameInfo,
    CheapSharkPriceEver,
    CheapSharkStore,
    CheapSharkStoreImages,
)
from backlog_manager_backend.repositories import (
    backlog_entry_repo,
    game_price_repo,
    user_game_price_alert_repo,
    user_repo,
)
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.game_price import GamePriceDeal, UpsertGamePriceParams
from backlog_manager_backend.schemas.user import CreateUserParams

_REAL_WEBHOOK_URL = "https://discord.com/api/webhooks/123456789012345678/token-abc"
_OTHER_REAL_WEBHOOK_URL = "https://discord.com/api/webhooks/987654321098765432/token-xyz"


@pytest.fixture
def price_service(monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    from backlog_manager_backend.services import price_service as module

    monkeypatch.setattr(module, "_store_names", {})
    monkeypatch.setattr(module, "_store_icons", {})
    return module


async def _fake_stores() -> list[CheapSharkStore]:
    return []


def _mock_no_stores(price_service: ModuleType, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(price_service, "get_stores", _fake_stores)


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


def _detail(*, price: str = "9.99", retail_price: str = "19.99", savings: str = "50.0") -> CheapSharkGameDetail:
    return CheapSharkGameDetail(
        info=CheapSharkGameInfo(title="Half-Life 2", steamAppID="220"),
        cheapestPriceEver=CheapSharkPriceEver(price="2.99", date=1234567890),
        deals=[
            CheapSharkDeal(
                storeID="1",
                dealID="deal-abc",
                price=price,
                retailPrice=retail_price,
                savings=savings,
            )
        ],
    )


async def test_get_price_info_uses_fresh_cache_without_refetching(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    await game_price_repo.upsert_game_price(
        session,
        UpsertGamePriceParams(
            steam_app_id=220,
            deals=[
                GamePriceDeal(store="Steam", icon="", price=9.99, retail_price=19.99, url="https://x")
            ],
            on_sale=True,
            checked_at=datetime.now(UTC).replace(tzinfo=None),
        ),
    )

    async def _fail(*args: object, **kwargs: object) -> None:
        raise AssertionError("should not refetch a fresh price")

    monkeypatch.setattr(price_service, "find_cheapshark_game_id", _fail)

    info = await price_service.get_price_info(session, 220)
    assert info.on_sale is True


async def test_get_price_info_refetches_when_stale(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    stale_checked_at = datetime.now(UTC).replace(tzinfo=None) - timedelta(hours=2)
    await game_price_repo.upsert_game_price(
        session,
        UpsertGamePriceParams(
            steam_app_id=220,
            deals=[
                GamePriceDeal(store="Steam", icon="", price=19.99, retail_price=19.99, url="https://x")
            ],
            on_sale=False,
            checked_at=stale_checked_at,
        ),
    )

    async def fake_find(steam_app_id: int) -> int:
        return 612

    async def fake_detail(cheapshark_game_id: int) -> CheapSharkGameDetail:
        return _detail()

    async def fake_stores() -> list[CheapSharkStore]:
        return [
            CheapSharkStore(
                storeID="1",
                storeName="Steam",
                isActive=1,
                images=CheapSharkStoreImages(
                    icon="/img/stores/icons/0.png",
                    logo="/img/stores/logos/0.png",
                    banner="/img/stores/banners/0.png",
                ),
            )
        ]

    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "get_stores", fake_stores)

    info = await price_service.get_price_info(session, 220)

    assert info.on_sale is True
    assert info.deals == [
        GamePriceDeal(
            store="Steam",
            icon="https://www.cheapshark.com/img/stores/icons/0.png",
            price=9.99,
            retail_price=19.99,
            url="https://www.cheapshark.com/redirect?dealID=deal-abc",
        )
    ]
    assert info.cheapest_price_ever == Decimal("2.99")


async def test_get_price_info_handles_no_cheapshark_match(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    _mock_no_stores(price_service, monkeypatch)

    async def fake_find(steam_app_id: int) -> None:
        return None

    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)

    info = await price_service.get_price_info(session, 999999)

    assert info.deals == []
    assert info.on_sale is False


async def test_check_prices_and_alert_sends_discord_message_when_newly_on_sale(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)

    async def fake_find(steam_app_id: int) -> int:
        return 612

    async def fake_detail(cheapshark_game_id: int) -> CheapSharkGameDetail:
        return _detail()

    sent: list[tuple[str, str]] = []

    async def fake_send(webhook_url: str, content: str) -> bool:
        sent.append((webhook_url, content))
        return True

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _mock_no_stores(price_service, monkeypatch)
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    alerts_sent = await price_service.check_prices_and_alert(session)

    assert alerts_sent == 1
    assert sent[0][0] == _REAL_WEBHOOK_URL
    assert "Half-Life 2" in sent[0][1]

    last_alerted = await user_game_price_alert_repo.get_last_alerted_price(session, user.id, 220)
    assert last_alerted == Decimal("9.99")


async def test_check_prices_and_alert_skips_owned_games(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=True)

    async def _fail(*args: object, **kwargs: object) -> None:
        raise AssertionError("owned games must not be swept")

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", _fail)

    alerts_sent = await price_service.check_prices_and_alert(session)
    assert alerts_sent == 0


async def test_check_prices_and_alert_noop_without_webhook(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)

    async def fake_find(steam_app_id: int) -> int:
        return 612

    async def fake_detail(cheapshark_game_id: int) -> CheapSharkGameDetail:
        return _detail()

    async def _fail_send(*args: object, **kwargs: object) -> None:
        raise AssertionError("must not call Discord without a configured webhook")

    monkeypatch.setattr(settings, "discord_webhook_url", None)
    _mock_no_stores(price_service, monkeypatch)
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", _fail_send)

    alerts_sent = await price_service.check_prices_and_alert(session)

    assert alerts_sent == 0
    price = await game_price_repo.get_game_price(session, 220)
    assert price is not None
    assert price.on_sale is True


async def test_check_prices_and_alert_does_not_repeat_same_price(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)

    async def fake_find(steam_app_id: int) -> int:
        return 612

    async def fake_detail(cheapshark_game_id: int) -> CheapSharkGameDetail:
        return _detail()

    sent: list[str] = []

    async def fake_send(webhook_url: str, content: str) -> bool:
        sent.append(content)
        return True

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _mock_no_stores(price_service, monkeypatch)
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    await price_service.check_prices_and_alert(session)
    second_run_alerts = await price_service.check_prices_and_alert(session)

    assert second_run_alerts == 0
    assert len(sent) == 1


async def test_check_prices_and_alert_notifies_each_user_independently(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    """Two users tracking the same on-sale game must each be notified,
    even if one of them was already alerted in a previous sweep - dedup
    is per (user, steam_app_id), not global on the shared GamePrice row."""
    from backlog_manager_backend.config import settings

    user1 = await _make_user(session, "priceowner1@example.com")
    await _make_entry(session, user1.id, steam_app_id=220, owned=False)

    async def fake_find(steam_app_id: int) -> int:
        return 612

    async def fake_detail(cheapshark_game_id: int) -> CheapSharkGameDetail:
        return _detail()

    sent: list[str] = []

    async def fake_send(webhook_url: str, content: str) -> bool:
        sent.append(webhook_url)
        return True

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _mock_no_stores(price_service, monkeypatch)
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    first_run_alerts = await price_service.check_prices_and_alert(session)
    assert first_run_alerts == 1

    user2 = await _make_user(session, "priceowner2@example.com")
    await _make_entry(session, user2.id, steam_app_id=220, owned=False)

    second_run_alerts = await price_service.check_prices_and_alert(session)

    assert second_run_alerts == 1
    assert sent == [_REAL_WEBHOOK_URL, _REAL_WEBHOOK_URL]


async def test_check_prices_and_alert_reverts_dedup_when_delivery_fails(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
    """A failed Discord send must not permanently block future alerts
    for this price - the claim is reverted so the next sweep retries."""
    from backlog_manager_backend.config import settings

    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)

    async def fake_find(steam_app_id: int) -> int:
        return 612

    async def fake_detail(cheapshark_game_id: int) -> CheapSharkGameDetail:
        return _detail()

    attempts: list[bool] = [False, True]

    async def flaky_send(webhook_url: str, content: str) -> bool:
        return attempts.pop(0)

    monkeypatch.setattr(settings, "discord_webhook_url", _REAL_WEBHOOK_URL)
    _mock_no_stores(price_service, monkeypatch)
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", flaky_send)

    first_run_alerts = await price_service.check_prices_and_alert(session)
    assert first_run_alerts == 0
    assert await user_game_price_alert_repo.get_last_alerted_price(session, user.id, 220) is None

    second_run_alerts = await price_service.check_prices_and_alert(session)
    assert second_run_alerts == 1
    assert await user_game_price_alert_repo.get_last_alerted_price(
        session, user.id, 220
    ) == Decimal("9.99")


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

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from types import ModuleType

import pytest
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
from backlog_manager_backend.schemas.game_price import UpsertGamePriceParams
from backlog_manager_backend.schemas.user import CreateUserParams


@pytest.fixture
def price_service(monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    from backlog_manager_backend.services import price_service as module

    monkeypatch.setattr(module, "_store_names", {})
    monkeypatch.setattr(module, "_store_icons", {})
    return module


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
            deals=[{"store": "Steam", "price": 9.99, "retail_price": 19.99}],
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
            deals=[{"store": "Steam", "price": 19.99, "retail_price": 19.99}],
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
        {
            "store": "Steam",
            "icon": "https://www.cheapshark.com/img/stores/icons/0.png",
            "price": 9.99,
            "retail_price": 19.99,
            "url": "https://www.cheapshark.com/redirect?dealID=deal-abc",
        }
    ]
    assert info.cheapest_price_ever == Decimal("2.99")


async def test_get_price_info_handles_no_cheapshark_match(
    price_service: ModuleType, monkeypatch: pytest.MonkeyPatch, session: AsyncSession
) -> None:
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

    async def fake_send(webhook_url: str, content: str) -> None:
        sent.append((webhook_url, content))

    monkeypatch.setattr(settings, "discord_webhook_url", "https://discord.example/webhook")
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    alerts_sent = await price_service.check_prices_and_alert(session)

    assert alerts_sent == 1
    assert sent[0][0] == "https://discord.example/webhook"
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

    monkeypatch.setattr(settings, "discord_webhook_url", "https://discord.example/webhook")
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

    async def fake_send(webhook_url: str, content: str) -> None:
        sent.append(content)

    monkeypatch.setattr(settings, "discord_webhook_url", "https://discord.example/webhook")
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

    async def fake_send(webhook_url: str, content: str) -> None:
        sent.append(webhook_url)

    monkeypatch.setattr(settings, "discord_webhook_url", "https://discord.example/global")
    monkeypatch.setattr(price_service, "find_cheapshark_game_id", fake_find)
    monkeypatch.setattr(price_service, "get_cheapshark_game_detail", fake_detail)
    monkeypatch.setattr(price_service, "send_discord_webhook_message", fake_send)

    first_run_alerts = await price_service.check_prices_and_alert(session)
    assert first_run_alerts == 1

    user2 = await _make_user(session, "priceowner2@example.com")
    await _make_entry(session, user2.id, steam_app_id=220, owned=False)

    second_run_alerts = await price_service.check_prices_and_alert(session)

    assert second_run_alerts == 1
    assert sent == [
        "https://discord.example/global",
        "https://discord.example/global",
    ]

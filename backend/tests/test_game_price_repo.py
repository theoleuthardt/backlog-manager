from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.repositories import backlog_entry_repo, game_price_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.game_price import GamePriceDeal, UpsertGamePriceParams
from backlog_manager_backend.schemas.user import CreateUserParams


async def _make_user(session: AsyncSession, email: str = "priceowner@example.com") -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username=email.split("@")[0], email=email, password_hash="h"),
    )


async def _make_entry(
    session: AsyncSession, user_id: int, *, steam_app_id: int | None, owned: bool = False
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


async def test_get_game_price_returns_none_when_absent(session: AsyncSession) -> None:
    assert await game_price_repo.get_game_price(session, 220) is None


async def test_upsert_game_price_creates_and_updates(session: AsyncSession) -> None:
    checked_at = datetime(2026, 1, 1, 12, 0, tzinfo=UTC).replace(tzinfo=None)
    created = await game_price_repo.upsert_game_price(
        session,
        UpsertGamePriceParams(
            steam_app_id=220,
            deals=[
                GamePriceDeal(
                    store="Steam", icon="", price=9.99, retail_price=19.99, url="https://x"
                )
            ],
            on_sale=True,
            checked_at=checked_at,
            cheapshark_game_id=612,
            cheapest_price_ever=Decimal("2.99"),
        ),
    )
    assert created.steam_app_id == 220
    assert created.on_sale is True
    assert created.deals == [
        GamePriceDeal(store="Steam", icon="", price=9.99, retail_price=19.99, url="https://x")
    ]

    updated = await game_price_repo.upsert_game_price(
        session,
        UpsertGamePriceParams(
            steam_app_id=220,
            deals=[
                GamePriceDeal(
                    store="Steam", icon="", price=19.99, retail_price=19.99, url="https://x"
                )
            ],
            on_sale=False,
            checked_at=checked_at,
        ),
    )
    assert updated.on_sale is False

    fetched = await game_price_repo.get_game_price(session, 220)
    assert fetched is not None
    assert fetched.on_sale is False


async def test_get_tracked_user_steam_app_id_pairs_filters_by_owned(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220, owned=False)
    await _make_entry(session, user.id, steam_app_id=None, owned=False)

    user2 = await _make_user(session, "priceowner2@example.com")
    await _make_entry(session, user2.id, steam_app_id=440, owned=True)

    unowned = await game_price_repo.get_tracked_user_steam_app_id_pairs(session, owned=False)
    assert unowned == [(user.id, 220)]

    everything = await game_price_repo.get_tracked_user_steam_app_id_pairs(session)
    assert set(everything) == {(user.id, 220), (user2.id, 440)}


async def test_get_title_for_user_steam_app_id(session: AsyncSession) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=220)

    assert (
        await game_price_repo.get_title_for_user_steam_app_id(session, user.id, 220)
        == "Half-Life 2"
    )
    assert await game_price_repo.get_title_for_user_steam_app_id(session, user.id, 9999) is None


async def test_get_title_for_user_steam_app_id_does_not_leak_other_users_titles(
    session: AsyncSession,
) -> None:
    """Two users can title the same Steam App ID's entry differently -
    a lookup for one user must never return the other user's title."""
    user1 = await _make_user(session, "titleowner1@example.com")
    await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user1.id,
            title="Half-Life 2",
            genre="FPS",
            platform="PC",
            status="Not Started",
            owned=False,
            interest=8,
            steam_app_id=220,
        ),
    )

    user2 = await _make_user(session, "titleowner2@example.com")
    await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user2.id,
            title="HL2 (my copy)",
            genre="FPS",
            platform="PC",
            status="Not Started",
            owned=False,
            interest=8,
            steam_app_id=220,
        ),
    )

    assert (
        await game_price_repo.get_title_for_user_steam_app_id(session, user1.id, 220)
        == "Half-Life 2"
    )
    assert (
        await game_price_repo.get_title_for_user_steam_app_id(session, user2.id, 220)
        == "HL2 (my copy)"
    )

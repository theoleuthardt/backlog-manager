from datetime import timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import SteamAppDetails
from backlog_manager_backend.repositories import steam_app_cache_repo
from backlog_manager_backend.utils import now_truncated_to_minute

MONTH = timedelta(days=30)


async def test_stored_names_come_back_for_the_asked_apps_only(session: AsyncSession) -> None:
    await steam_app_cache_repo.upsert_many(
        session,
        {
            620: SteamAppDetails(name="Portal 2", header_image="https://example.com/p2.jpg"),
            504230: SteamAppDetails(name="Celeste", header_image=None),
        },
    )

    found = await steam_app_cache_repo.get_fresh(session, [620, 1], MONTH)

    assert set(found) == {620}
    assert found[620].name == "Portal 2"
    assert found[620].header_image == "https://example.com/p2.jpg"


async def test_storing_an_app_again_updates_its_name(session: AsyncSession) -> None:
    await steam_app_cache_repo.upsert_many(session, {620: SteamAppDetails(name="Portal 2")})
    await steam_app_cache_repo.upsert_many(
        session, {620: SteamAppDetails(name="Portal 2: Remastered", header_image="x")}
    )

    found = await steam_app_cache_repo.get_fresh(session, [620], MONTH)

    assert found[620].name == "Portal 2: Remastered"
    assert found[620].header_image == "x"


async def test_names_older_than_the_maximum_age_are_not_returned(
    session: AsyncSession,
) -> None:
    long_ago = now_truncated_to_minute() - timedelta(days=45)
    await steam_app_cache_repo.upsert_many(
        session, {620: SteamAppDetails(name="Portal 2")}, resolved_at=long_ago
    )
    await steam_app_cache_repo.upsert_many(session, {10: SteamAppDetails(name="Counter-Strike")})

    found = await steam_app_cache_repo.get_fresh(session, [620, 10], MONTH)

    assert set(found) == {10}


async def test_asking_for_nothing_returns_nothing(session: AsyncSession) -> None:
    assert await steam_app_cache_repo.get_fresh(session, [], MONTH) == {}
    await steam_app_cache_repo.upsert_many(session, {})

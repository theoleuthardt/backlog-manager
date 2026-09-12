import asyncio
from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.integrations.types import (
    HltbResultData,
    SteamAchievement,
    SteamAchievementSchema,
    SteamAppDetails,
    SteamOwnedGame,
    SteamPlayerStats,
    SteamWishlistItem,
)
from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.user import CreateUserParams
from backlog_manager_backend.services import steam_service


@pytest.fixture(autouse=True)
def _no_hltb_match_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    """import_library looks up HowLongToBeat times unconditionally for
    every game - default every test to a real (empty) function rather
    than a live network call, since most tests here don't care about
    hltb fields. Tests that do override this via their own monkeypatch."""

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        return []

    monkeypatch.setattr(steam_service, "search_game_on_hltb", fake_search_game_on_hltb)


async def _make_user(session: AsyncSession, steam_id: str | None = "76561197960287930") -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(
            username="steamuser",
            email="steamuser@example.com",
            password_hash="h",
            steam_id=steam_id,
        ),
    )


async def _make_entry(session: AsyncSession, user_id: int, **overrides: object) -> object:
    return await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user_id,
            title=overrides.get("title", "Celeste"),
            genre="Platformer",
            platform="PC",
            status="In Progress",
            owned=True,
            interest=8,
            steam_app_id=overrides.get("steam_app_id"),
            playtime=overrides.get("playtime"),
        ),
    )


async def test_sync_playtimes_raises_when_steam_not_linked(session: AsyncSession) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.sync_playtimes(session, user, "api-key")


async def test_sync_playtimes_updates_matching_entries(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    matching = await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("1.00"))
    await _make_entry(session, user.id, title="No Steam Link", steam_app_id=None)
    await _make_entry(session, user.id, title="Not Owned On Steam", steam_app_id=999)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        assert steam_id == user.steam_id
        assert api_key == "api-key"
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert len(updated) == 1
    assert updated[0].backlog_entry_id == matching.backlog_entry_id
    assert updated[0].playtime == Decimal("8.50")


async def test_sync_playtimes_skips_entries_already_up_to_date(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("8.50"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert updated == []


async def test_import_library_raises_when_steam_not_linked(session: AsyncSession) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.import_library(session, user, "api-key")


async def test_import_library_creates_entries_for_new_owned_games(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("8.50"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        assert steam_id == user.steam_id
        assert api_key == "api-key"
        return [
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
            SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120),
        ]

    async def fake_get_library_cover(app_id: int) -> str | None:
        assert app_id == 620
        return "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg"

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(
        steam_service.steam_integration,
        "get_steam_library_cover_if_exists",
        fake_get_library_cover,
    )

    created = await steam_service.import_library(session, user, "api-key")

    assert len(created) == 1
    assert created[0].title == "Portal 2"
    assert created[0].steam_app_id == 620
    assert created[0].playtime == Decimal("2.00")
    assert created[0].status == "Not Started"
    assert created[0].owned is True
    assert created[0].image_link == "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg"


async def test_import_library_sets_cover_when_steamgriddb_key_is_given(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120)]

    async def fake_get_game_covers(steam_app_id: int, api_key: str) -> list[str]:
        assert steam_app_id == 620
        assert api_key == "griddb-key"
        return ["https://cdn2.steamgriddb.com/grid/1.png"]

    async def fake_get_library_cover(app_id: int) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service.game_service, "get_game_covers", fake_get_game_covers)
    monkeypatch.setattr(
        "backlog_manager_backend.integrations.steam.get_steam_library_cover_if_exists",
        fake_get_library_cover,
    )

    created = await steam_service.import_library(
        session, user, "api-key", steamgriddb_api_key="griddb-key"
    )

    assert created[0].image_link == "https://cdn2.steamgriddb.com/grid/1.png"


async def test_import_library_continues_without_a_cover_when_steamgriddb_fails(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A SteamGridDB outage (or a missing key) while importing must not
    fail the import - the game still gets created, just without a
    cover, the same as if steamgriddb_api_key were never passed."""
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120)]

    async def fake_get_game_covers(steam_app_id: int, api_key: str) -> list[str]:
        request = httpx.Request("GET", "https://example.com")
        raise httpx.HTTPStatusError(
            "boom", request=request, response=httpx.Response(503, request=request)
        )

    async def fake_get_library_cover(app_id: int) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service.game_service, "get_game_covers", fake_get_game_covers)
    monkeypatch.setattr(
        steam_service.steam_integration,
        "get_steam_library_cover_if_exists",
        fake_get_library_cover,
    )

    created = await steam_service.import_library(
        session, user, "api-key", steamgriddb_api_key="griddb-key"
    )

    assert len(created) == 1
    assert created[0].image_link is None


async def test_import_library_sets_hltb_times_when_a_match_is_found(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120)]

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        assert search_term == "Portal 2"
        return [
            HltbResultData(
                id=1,
                hltb_id=1,
                title="Portal 2",
                image_url="https://example.com/portal2.jpg",
                main_story=8.5,
                main_story_with_extras=11.0,
                completionist=21.5,
                last_updated_at="2024-01-01",
            )
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "search_game_on_hltb", fake_search_game_on_hltb)

    created = await steam_service.import_library(session, user, "api-key")

    assert created[0].main_time == Decimal("8.5")
    assert created[0].main_plus_extra_time == Decimal("11.0")
    assert created[0].completion_time == Decimal("21.5")


async def test_import_library_leaves_times_blank_when_hltb_has_no_match(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The autouse _no_hltb_match_by_default fixture already returns no
    match - this just makes the resulting behavior explicit."""
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Some Obscure Game", playtime_forever=120)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(session, user, "api-key")

    assert created[0].main_time is None
    assert created[0].main_plus_extra_time is None
    assert created[0].completion_time is None


async def test_import_library_creates_nothing_when_all_games_already_linked(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("8.50"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(session, user, "api-key")

    assert created == []


async def test_import_library_uses_a_provided_owned_games_snapshot(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    call_count = 0

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        nonlocal call_count
        call_count += 1
        return []

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(
        session, user, "api-key", [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120)]
    )

    assert call_count == 0
    assert len(created) == 1
    assert created[0].title == "Portal 2"


async def test_import_library_skips_a_game_that_becomes_a_duplicate_mid_import(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
            SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120),
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    original_create_backlog_entry = backlog_entry_repo.create_backlog_entry

    async def flaky_create_backlog_entry(
        session: AsyncSession, params: CreateBacklogEntryParams
    ) -> object:
        if params.steam_app_id == 504230:
            raise ConflictError("A resource with this identifier already exists")
        return await original_create_backlog_entry(session, params)

    monkeypatch.setattr(backlog_entry_repo, "create_backlog_entry", flaky_create_backlog_entry)

    created = await steam_service.import_library(session, user, "api-key")

    assert len(created) == 1
    assert created[0].title == "Portal 2"


async def test_import_library_includes_family_members_games(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        if steam_id == user.steam_id:
            return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]
        assert steam_id == "family-member-1"
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=999)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(
        session, user, "api-key", family_steam_ids=["family-member-1"]
    )

    titles = {entry.title for entry in created}
    assert titles == {"Celeste", "Portal 2"}


async def test_import_library_zeroes_playtime_for_family_only_games(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        if steam_id == user.steam_id:
            return []
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=999)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(
        session, user, "api-key", family_steam_ids=["family-member-1"]
    )

    assert len(created) == 1
    assert created[0].title == "Portal 2"
    assert created[0].playtime == Decimal("0.00")


async def test_import_library_does_not_duplicate_a_game_owned_by_user_and_family(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(
        session, user, "api-key", family_steam_ids=["family-member-1", "family-member-2"]
    )

    assert len(created) == 1
    assert created[0].playtime == Decimal("2.00")


async def test_import_library_skips_a_family_member_whose_fetch_fails(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        if steam_id == user.steam_id:
            return []
        if steam_id == "broken-member":
            raise httpx.ConnectError(
                "connection refused", request=httpx.Request("GET", "https://example.com")
            )
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(
        session, user, "api-key", family_steam_ids=["broken-member", "working-member"]
    )

    assert len(created) == 1
    assert created[0].title == "Portal 2"


async def test_import_library_skips_a_game_that_fails_for_a_non_conflict_reason(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Hardening for issue #154's Steam-sync-drops-games report: only
    ConflictError (an already-imported duplicate) was ever caught per
    item, so any other exception raised while creating one entry (a
    decode quirk, an unmapped database error, ...) would propagate out
    of the whole loop and abort the entire import, silently discarding
    every game after the one that failed - even though earlier entries
    in the loop had already been committed individually. One bad game
    must not prevent the rest of the library from being imported.

    The failing entry raises during the real `session.commit()` (a
    genuine aborted-transaction error from Postgres), not from a mock
    that never touches the session - this exercises import_library's
    `except Exception` branch actually needing to roll the session
    back before the next iteration's commit, not just needing to
    catch-and-continue."""
    from sqlalchemy import text

    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
            SteamOwnedGame(appid=1465360, name="SnowRunner", playtime_forever=120),
            SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=90),
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    original_create_backlog_entry = backlog_entry_repo.create_backlog_entry

    async def flaky_create_backlog_entry(
        session: AsyncSession, params: CreateBacklogEntryParams
    ) -> object:
        if params.steam_app_id == 1465360:
            await session.execute(text("SELECT 1/0"))
        return await original_create_backlog_entry(session, params)

    monkeypatch.setattr(backlog_entry_repo, "create_backlog_entry", flaky_create_backlog_entry)

    created = await steam_service.import_library(session, user, "api-key")

    titles = {entry.title for entry in created}
    assert titles == {"Celeste", "Portal 2"}


async def test_sync_playtimes_and_import_raises_when_steam_not_linked(
    session: AsyncSession,
) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.sync_playtimes_and_import(session, user, "api-key", auto_import=True)


async def test_sync_playtimes_and_import_fetches_owned_games_only_once(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("1.00"))
    call_count = 0

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        nonlocal call_count
        call_count += 1
        return [
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
            SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120),
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes_and_import(
        session, user, "api-key", auto_import=True
    )

    assert call_count == 1
    titles = {entry.title for entry in updated}
    assert titles == {"Celeste", "Portal 2"}


async def test_sync_playtimes_and_import_skips_import_when_auto_import_is_off(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("1.00"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
            SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120),
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes_and_import(
        session, user, "api-key", auto_import=False
    )

    titles = {entry.title for entry in updated}
    assert titles == {"Celeste"}


async def test_import_library_concurrent_calls_do_not_create_duplicate_entries(
    postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.db import async_session

    async with async_session() as setup_session:
        user = await user_repo.create_user(
            setup_session,
            CreateUserParams(
                username="concurrentsteamuser",
                email="concurrentsteamuser@example.com",
                password_hash="h",
                steam_id="76561197960287930",
            ),
        )

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    async def run_import() -> list[object]:
        async with async_session() as session:
            return await steam_service.import_library(session, user, "api-key")

    first_created, second_created = await asyncio.gather(run_import(), run_import())

    assert len(first_created) + len(second_created) == 1

    async with async_session() as verify_session:
        entries = await backlog_entry_repo.get_backlog_entries_by_user(verify_session, user.id)
    assert len(entries) == 1


async def test_get_achievement_progress_raises_when_steam_not_linked(
    session: AsyncSession,
) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.get_achievement_progress(user, "api-key", 504230)


async def test_get_achievement_progress_returns_empty_when_app_has_no_stats(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_player_achievements(
        steam_id: str, app_id: int, api_key: str
    ) -> SteamPlayerStats:
        return SteamPlayerStats(success=False, achievements=[])

    monkeypatch.setattr(steam_service, "get_player_achievements", fake_get_player_achievements)

    progress = await steam_service.get_achievement_progress(user, "api-key", 504230)

    assert progress.unlocked == 0
    assert progress.total == 0
    assert progress.achievements == []


async def test_get_achievement_progress_combines_player_stats_and_schema(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    monkeypatch.setattr(steam_service, "_achievement_schema_cache", {})

    async def fake_get_player_achievements(
        steam_id: str, app_id: int, api_key: str
    ) -> SteamPlayerStats:
        return SteamPlayerStats(
            success=True,
            achievements=[
                SteamAchievement(
                    apiname="ach_a", achieved=1, unlocktime=1000, name="A", description="fallback"
                ),
                SteamAchievement(apiname="ach_b", achieved=0, unlocktime=0, name="B"),
            ],
        )

    async def fake_get_achievement_schema(
        app_id: int, api_key: str
    ) -> list[SteamAchievementSchema]:
        return [
            SteamAchievementSchema(
                name="ach_a",
                display_name="Achievement A",
                description="Do the thing",
                icon="https://example.com/a.jpg",
            )
        ]

    monkeypatch.setattr(steam_service, "get_player_achievements", fake_get_player_achievements)
    monkeypatch.setattr(steam_service, "get_achievement_schema", fake_get_achievement_schema)

    progress = await steam_service.get_achievement_progress(user, "api-key", 504230)

    assert progress.unlocked == 1
    assert progress.total == 2
    first, second = progress.achievements
    assert first.apiname == "ach_a"
    assert first.display_name == "Achievement A"
    assert first.description == "Do the thing"
    assert first.icon == "https://example.com/a.jpg"
    assert first.achieved is True
    assert first.hidden is False
    assert second.apiname == "ach_b"
    assert second.display_name == "B"
    assert second.icon is None
    assert second.achieved is False
    assert second.hidden is False


async def test_get_achievement_progress_marks_hidden_achievements(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Steam omits description for a secret achievement until it's
    unlocked - that's the schema's hidden flag, not missing data, so
    it's surfaced on AchievementInfo rather than just silently leaving
    description blank."""
    user = await _make_user(session)
    monkeypatch.setattr(steam_service, "_achievement_schema_cache", {})

    async def fake_get_player_achievements(
        steam_id: str, app_id: int, api_key: str
    ) -> SteamPlayerStats:
        return SteamPlayerStats(
            success=True,
            achievements=[SteamAchievement(apiname="secret", achieved=0, unlocktime=0)],
        )

    async def fake_get_achievement_schema(
        app_id: int, api_key: str
    ) -> list[SteamAchievementSchema]:
        return [
            SteamAchievementSchema(name="secret", display_name="???", description=None, hidden=1)
        ]

    monkeypatch.setattr(steam_service, "get_player_achievements", fake_get_player_achievements)
    monkeypatch.setattr(steam_service, "get_achievement_schema", fake_get_achievement_schema)

    progress = await steam_service.get_achievement_progress(user, "api-key", 504230)

    assert progress.achievements[0].hidden is True
    assert progress.achievements[0].description is None


async def test_get_achievement_progress_falls_back_when_schema_fetch_fails(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    monkeypatch.setattr(steam_service, "_achievement_schema_cache", {})

    async def fake_get_player_achievements(
        steam_id: str, app_id: int, api_key: str
    ) -> SteamPlayerStats:
        return SteamPlayerStats(
            success=True,
            achievements=[
                SteamAchievement(
                    apiname="ach_a", achieved=1, unlocktime=1000, name="A", description="desc"
                )
            ],
        )

    async def failing_get_achievement_schema(
        app_id: int, api_key: str
    ) -> list[SteamAchievementSchema]:
        raise httpx.ConnectError("connection refused")

    monkeypatch.setattr(steam_service, "get_player_achievements", fake_get_player_achievements)
    monkeypatch.setattr(steam_service, "get_achievement_schema", failing_get_achievement_schema)

    progress = await steam_service.get_achievement_progress(user, "api-key", 504230)

    assert progress.total == 1
    assert progress.achievements[0].display_name == "A"
    assert progress.achievements[0].description == "desc"
    assert progress.achievements[0].icon is None


async def test_get_achievement_progress_caches_schema_across_calls(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    monkeypatch.setattr(steam_service, "_achievement_schema_cache", {})
    call_count = 0

    async def fake_get_player_achievements(
        steam_id: str, app_id: int, api_key: str
    ) -> SteamPlayerStats:
        return SteamPlayerStats(
            success=True,
            achievements=[SteamAchievement(apiname="ach_a", achieved=1, name="A")],
        )

    async def fake_get_achievement_schema(
        app_id: int, api_key: str
    ) -> list[SteamAchievementSchema]:
        nonlocal call_count
        call_count += 1
        return []

    monkeypatch.setattr(steam_service, "get_player_achievements", fake_get_player_achievements)
    monkeypatch.setattr(steam_service, "get_achievement_schema", fake_get_achievement_schema)

    await steam_service.get_achievement_progress(user, "api-key", 504230)
    await steam_service.get_achievement_progress(user, "api-key", 504230)

    assert call_count == 1


async def test_preview_wishlist_lists_unlinked_games_with_titles_and_covers(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230)

    async def fake_get_wishlist(steam_id: str) -> list[SteamWishlistItem]:
        assert steam_id == user.steam_id
        return [
            SteamWishlistItem(appid=620, priority=0, date_added=1600000000),
            SteamWishlistItem(appid=504230, priority=1, date_added=1600000100),
        ]

    async def fake_get_steam_app_details(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        return {
            620: SteamAppDetails(name="Portal 2", header_image="https://example.com/portal2.jpg"),
            504230: SteamAppDetails(name="Celeste", header_image=None),
        }

    async def fake_try_get_cover(steam_app_id: int, key: str | None) -> str | None:
        return {
            620: "https://example.com/portal2.jpg",
        }.get(steam_app_id)

    monkeypatch.setattr(steam_service, "get_wishlist", fake_get_wishlist)
    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", fake_try_get_cover)

    preview = await steam_service.preview_wishlist(session, user)

    assert len(preview) == 1
    assert preview[0].steam_app_id == 620
    assert preview[0].title == "Portal 2"
    assert preview[0].image_link == "https://example.com/portal2.jpg"


async def test_preview_wishlist_raises_when_steam_not_linked(session: AsyncSession) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.preview_wishlist(session, user)


async def test_import_wishlist_creates_entries_as_not_owned(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230)

    async def fake_get_wishlist(steam_id: str) -> list[SteamWishlistItem]:
        assert steam_id == user.steam_id
        return [
            SteamWishlistItem(appid=620, priority=0, date_added=1600000000),
            SteamWishlistItem(appid=504230, priority=1, date_added=1600000100),
        ]

    async def fake_get_steam_app_details(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        return {
            620: SteamAppDetails(name="Portal 2", header_image="https://example.com/portal2.jpg")
        }

    async def fake_get_wishlist_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "get_wishlist", fake_get_wishlist)
    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", fake_get_wishlist_cover)

    created = await steam_service.import_wishlist(
        session, user, [SteamWishlistItem(appid=620, priority=0, date_added=1600000000)]
    )

    assert len(created) == 1
    assert created[0].title == "Portal 2"
    assert created[0].status == "Not Owned"
    assert created[0].owned is False
    assert created[0].steam_app_id == 620


async def test_import_wishlist_deduplicates_repeated_app_ids(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_steam_app_details(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        assert app_ids == [620]
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    async def fake_try_get_cover(app_id: int, key: str | None) -> str | None:
        return f"https://example.com/cover-{app_id}.jpg"

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", fake_try_get_cover)

    created = await steam_service.import_wishlist(
        session,
        user,
        [
            SteamWishlistItem(appid=620, priority=0, date_added=1600000000),
            SteamWishlistItem(appid=620, priority=1, date_added=1600000100),
        ],
    )

    assert len(created) == 1
    assert created[0].steam_app_id == 620


async def test_import_wishlist_requires_linked_account(session: AsyncSession) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.import_wishlist(session, user, [])


async def test_preview_library_lists_unlinked_owned_games(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        assert steam_id == user.steam_id
        return [
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
            SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120),
        ]

    async def fake_get_wishlist_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", fake_get_wishlist_cover)

    preview = await steam_service.preview_library(session, user, "api-key")

    assert [item.steam_app_id for item in preview] == [620]
    assert preview[0].title == "Portal 2"

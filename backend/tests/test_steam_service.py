import asyncio
import time
from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.integrations.types import (
    EnrichedResult,
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


async def test_sync_playtimes_matches_unlinked_entry_by_title(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    unlinked = await _make_entry(
        session, user.id, title="Elden Ring", steam_app_id=None, playtime=Decimal("1.00")
    )

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [
            SteamOwnedGame(appid=1245620, name="ELDEN RING", playtime_forever=3300),
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert len(updated) == 1
    assert updated[0].backlog_entry_id == unlinked.backlog_entry_id
    assert updated[0].playtime == Decimal("55.00")


async def test_sync_playtimes_requires_exact_title_match_for_unlinked_entries(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Skyrim", steam_app_id=None, playtime=Decimal("1.00"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [
            SteamOwnedGame(appid=489830, name="The Elder Scrolls V: Skyrim", playtime_forever=3300)
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert updated == []


async def test_sync_playtimes_title_fallback_skips_app_claimed_by_linked_entry(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(
        session, user.id, title="ELDEN RING", steam_app_id=1245620, playtime=Decimal("1.00")
    )
    await _make_entry(
        session, user.id, title="ELDEN RING", steam_app_id=None, playtime=Decimal("1.00")
    )

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=1245620, name="ELDEN RING", playtime_forever=3300)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert len(updated) == 1
    assert updated[0].steam_app_id == 1245620


async def test_sync_playtimes_title_fallback_skips_ambiguous_entry_title(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Tetris", steam_app_id=None, playtime=Decimal("1.00"))
    await _make_entry(session, user.id, title="TETRIS", steam_app_id=None, playtime=Decimal("1.00"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=1001, name="Tetris", playtime_forever=60)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert updated == []


async def test_sync_playtimes_normalizes_trademark_symbols_in_unlinked_title_match(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(
        session, user.id, title="Elden Ring", steam_app_id=None, playtime=Decimal("1.00")
    )

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=1245620, name="ELDEN RING™", playtime_forever=3300)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert len(updated) == 1
    assert updated[0].playtime == Decimal("55.00")


async def test_sync_playtimes_skips_unlinked_entry_with_ambiguous_title(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Tetris", steam_app_id=None, playtime=Decimal("1.00"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [
            SteamOwnedGame(appid=1001, name="Tetris", playtime_forever=60),
            SteamOwnedGame(appid=1002, name="TETRIS", playtime_forever=9999),
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert updated == []


async def test_get_library_playtime_returns_hours_for_owned_app(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        assert steam_id == "76561197960287930"
        return [SteamOwnedGame(appid=1245620, name="ELDEN RING", playtime_forever=3300)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    playtime = await steam_service.get_library_playtime("76561197960287930", "api-key", 1245620)

    assert playtime == Decimal("55.00")


async def test_get_library_playtime_returns_none_for_unowned_app(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    playtime = await steam_service.get_library_playtime("76561197960287930", "api-key", 1245620)

    assert playtime is None


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
    assert (
        created[0].image_link
        == "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg"
    )


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

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
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

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
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

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
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


async def test_operation_budget_bounds_concurrent_lookups(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Issue #184: the per-operation lookup budget must cap how many
    external lookups are in flight at once, not just how many total."""
    user = await _make_user(session)
    app_ids = [620 + i for i in range(12)]

    in_flight = 0
    peak_in_flight = 0

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {
            app_id: SteamAppDetails(name=f"Game {app_id}", header_image=None) for app_id in app_ids
        }

    async def tracking_cover(app_id: int, key: str | None) -> str | None:
        nonlocal in_flight, peak_in_flight
        in_flight += 1
        peak_in_flight = max(peak_in_flight, in_flight)
        await asyncio.sleep(0.01)
        in_flight -= 1
        return None

    async def fake_get_wishlist(steam_id: str) -> list[SteamWishlistItem]:
        return [SteamWishlistItem(appid=app_id) for app_id in app_ids]

    monkeypatch.setattr(steam_service, "get_wishlist", fake_get_wishlist)
    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", tracking_cover)

    preview = await steam_service.preview_wishlist(session, user)

    assert len(preview) == len(app_ids)
    assert peak_in_flight <= steam_service._LOOKUP_CONCURRENCY


async def test_operation_budget_returns_fallback_once_deadline_passed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Issue #184: once the operation's deadline has passed, no new
    lookup may start - the affected fields degrade to their fallbacks
    and the import still completes."""
    cover_calls = 0

    async def counting_cover(app_id: int, key: str | None) -> str | None:
        nonlocal cover_calls
        cover_calls += 1
        return f"https://example.com/cover-{app_id}.jpg"

    monkeypatch.setattr(steam_service, "_try_get_cover", counting_cover)

    budget = steam_service._OperationBudget()
    budget.deadline = 0.0

    assert await budget.lookup(lambda: counting_cover(620, None), None) is None
    assert await budget.lookup(lambda: counting_cover(620, None), "fallback") == "fallback"
    assert cover_calls == 0


async def test_operation_budget_returns_fallback_when_active_lookup_exceeds_deadline(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A lookup that *starts* before the deadline must not be allowed to
    run past it - otherwise a hung request keeps the per-user operation
    lock held forever despite the budget."""
    started = False

    async def hanging_lookup() -> str:
        nonlocal started
        started = True
        await asyncio.sleep(30)

    budget = steam_service._OperationBudget()
    budget.deadline = time.monotonic() + 0.05

    assert await budget.lookup(hanging_lookup, "fallback") == "fallback"
    assert started


async def test_import_wishlist_uses_capsule_cover_when_budget_skips_lookup(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A skipped cover lookup (budget spent) must still import the item,
    with the deterministic CDN capsule as the cover rather than None."""
    user = await _make_user(session)

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {
            app_id: SteamAppDetails(name=f"Game {app_id}", header_image=None) for app_id in app_ids
        }

    async def unreachable_cover(app_id: int, key: str | None) -> str | None:
        raise AssertionError("cover lookup must not run once the budget is spent")

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", unreachable_cover)

    original_budget = steam_service._OperationBudget

    class SpentBudget(original_budget):
        def __init__(self) -> None:
            super().__init__()
            self.deadline = 0.0

    monkeypatch.setattr(steam_service, "_OperationBudget", SpentBudget)

    created = await steam_service.import_wishlist(session, user, [SteamWishlistItem(appid=620)])

    assert len(created) == 1
    assert created[0].image_link == (
        "https://cdn.cloudflare.steamstatic.com/steam/apps/620/capsule_sm_120.jpg"
    )


async def test_import_library_uses_fallbacks_when_budget_deadline_passed(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Issue #184: an exhausted lookup budget must not block the import -
    entries are still created, with no cover and no HLTB times."""
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120)]

    async def unreachable_cover(app_id: int, key: str | None) -> str | None:
        raise AssertionError("cover lookup must not run once the budget is spent")

    async def unreachable_hltb(title: str) -> tuple[None, None, None]:
        raise AssertionError("HLTB lookup must not run once the budget is spent")

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", unreachable_cover)
    monkeypatch.setattr(steam_service, "_try_get_hltb_times", unreachable_hltb)

    original_budget = steam_service._OperationBudget

    class SpentBudget(original_budget):
        def __init__(self) -> None:
            super().__init__()
            self.deadline = 0.0

    monkeypatch.setattr(steam_service, "_OperationBudget", SpentBudget)

    created = await steam_service.import_library(session, user, "api-key")

    assert len(created) == 1
    assert created[0].steam_app_id == 620
    assert created[0].image_link is None
    assert created[0].main_time is None


async def test_sync_playtimes_and_import_updates_the_users_space_playtime(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.repositories import space_entry_member_repo, space_repo

    user = await _make_user(session)
    other = await user_repo.create_user(
        session,
        CreateUserParams(
            username="steampartner", email="steampartner@example.com", password_hash="h"
        ),
    )
    space_id = await space_repo.create_space(session, user.id)
    await space_repo.add_invited_member(session, space_id, other.id)
    shared = await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=other.id,
            space_id=space_id,
            title="Celeste",
            genre="Platformer",
            platform="PC",
            status="In Progress",
            owned=True,
            interest=8,
            steam_app_id=504230,
        ),
    )

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes_and_import(
        session, user, "api-key", auto_import=False
    )
    [mine] = await space_entry_member_repo.apply_member_data(session, [shared], user.id)
    [theirs] = await space_entry_member_repo.apply_member_data(session, [shared], other.id)

    assert updated == []
    assert mine.playtime == Decimal("8.50")
    assert theirs.playtime is None
    assert theirs.partner_playtime == Decimal("8.50")
    assert await backlog_entry_repo.get_backlog_entries_by_user(session, user.id) == []


async def test_import_library_strips_trademark_symbols_from_titles(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=1091500, name="Cyberpunk 2077®", playtime_forever=0)]

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    hltb_titles: list[str] = []

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        hltb_titles.append(search_term)
        return []

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    monkeypatch.setattr(steam_service, "search_game_on_hltb", fake_search_game_on_hltb)

    created = await steam_service.import_library(session, user, "api-key")

    assert [entry.title for entry in created] == ["Cyberpunk 2077"]
    assert hltb_titles == ["Cyberpunk 2077"]


async def test_preview_library_strips_trademark_symbols_from_titles(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=1, name="DOOM™ Eternal ©", playtime_forever=0)]

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)

    preview = await steam_service.preview_library(session, user, "api-key")

    assert [item.title for item in preview] == ["DOOM Eternal"]


async def test_preview_and_import_wishlist_strip_trademark_symbols_from_titles(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    item = SteamWishlistItem(appid=292030, priority=0, date_added=1600000000)

    async def fake_get_wishlist(steam_id: str) -> list[SteamWishlistItem]:
        return [item]

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {292030: SteamAppDetails(name="The Witcher® 3: Wild Hunt™", header_image=None)}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "get_wishlist", fake_get_wishlist)
    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)

    preview = await steam_service.preview_wishlist(session, user)
    created = await steam_service.import_wishlist(session, user, [item])

    assert [entry.title for entry in preview] == ["The Witcher 3: Wild Hunt"]
    assert [entry.title for entry in created] == ["The Witcher 3: Wild Hunt"]


def _igdb_result(**overrides: object) -> EnrichedResult:
    fields: dict[str, object] = {
        "id": 1,
        "hltb_id": 1,
        "title": "Cyberpunk 2077",
        "image_url": None,
        "genres": ["RPG", "Shooter"],
        "platforms": [],
        "main_story": 25.0,
        "main_story_with_extras": 60.0,
        "completionist": 100.0,
        "description": "Open world RPG",
        "trailer_url": "https://www.youtube.com/watch?v=trailer0001",
    }
    fields.update(overrides)
    return EnrichedResult(**fields)


async def test_import_library_enriches_entries_with_igdb_data(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    searched: list[tuple[str, str, str, int]] = []

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=1091500, name="Cyberpunk 2077™", playtime_forever=0)]

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    async def fake_search(
        title: str, client_id: str, client_secret: str, steamgriddb_api_key: str | None, **kwargs
    ) -> list[EnrichedResult]:
        searched.append((title, client_id, client_secret, kwargs["limit"]))
        return [_igdb_result()]

    async def hltb_must_not_run(search_term: str) -> list[HltbResultData]:
        raise AssertionError("HLTB is only the fallback when IGDB has no beat-times")

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    monkeypatch.setattr(steam_service.game_service, "search", fake_search)
    monkeypatch.setattr(steam_service, "search_game_on_hltb", hltb_must_not_run)

    [entry] = await steam_service.import_library(
        session, user, "api-key", igdb_credentials=("cid", "secret")
    )

    assert searched == [("Cyberpunk 2077", "cid", "secret", 1)]
    assert entry.genre == "RPG, Shooter"
    assert entry.description == "Open world RPG"
    assert entry.trailer_link == "https://www.youtube.com/watch?v=trailer0001"
    assert entry.main_time == Decimal("25.0")
    assert entry.main_plus_extra_time == Decimal("60.0")
    assert entry.completion_time == Decimal("100.0")


async def test_import_library_falls_back_to_hltb_when_the_igdb_match_has_no_times(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=1, name="Obscure Game", playtime_forever=0)]

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    async def fake_search(*args: object, **kwargs: object) -> list[EnrichedResult]:
        return [_igdb_result(main_story=0.0, main_story_with_extras=0.0, completionist=0.0)]

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        return [
            HltbResultData(
                id=5,
                hltb_id=5,
                title="Obscure Game",
                image_url="",
                main_story=7.0,
                main_story_with_extras=9.0,
                completionist=12.0,
                last_updated_at="2024-01-01",
            )
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    monkeypatch.setattr(steam_service.game_service, "search", fake_search)
    monkeypatch.setattr(steam_service, "search_game_on_hltb", fake_search_game_on_hltb)

    [entry] = await steam_service.import_library(
        session, user, "api-key", igdb_credentials=("cid", "secret")
    )

    assert entry.genre == "RPG, Shooter"
    assert entry.main_time == Decimal("7.0")
    assert entry.completion_time == Decimal("12.0")


async def test_import_library_still_imports_when_igdb_is_unreachable(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=0)]

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    async def failing_search(*args: object, **kwargs: object) -> list[EnrichedResult]:
        raise httpx.ConnectError("boom")

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    monkeypatch.setattr(steam_service.game_service, "search", failing_search)

    [entry] = await steam_service.import_library(
        session, user, "api-key", igdb_credentials=("cid", "secret")
    )

    assert entry.title == "Portal 2"
    assert entry.genre == ""
    assert entry.description is None


async def test_import_library_skips_igdb_without_credentials(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=0)]

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    async def search_must_not_run(*args: object, **kwargs: object) -> list[EnrichedResult]:
        raise AssertionError("IGDB must not be queried without credentials")

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    monkeypatch.setattr(steam_service.game_service, "search", search_must_not_run)

    [entry] = await steam_service.import_library(session, user, "api-key")

    assert entry.genre == ""


async def test_import_wishlist_enriches_entries_with_igdb_data(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    searched: list[str] = []

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {292030: SteamAppDetails(name="The Witcher® 3: Wild Hunt", header_image=None)}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    async def fake_search(title: str, *args: object, **kwargs: object) -> list[EnrichedResult]:
        searched.append(title)
        return [_igdb_result(genres=["RPG"], description="Monster hunter")]

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    monkeypatch.setattr(steam_service.game_service, "search", fake_search)

    [entry] = await steam_service.import_wishlist(
        session,
        user,
        [SteamWishlistItem(appid=292030, priority=0, date_added=1600000000)],
        igdb_credentials=("cid", "secret"),
    )

    assert searched == ["The Witcher 3: Wild Hunt"]
    assert entry.genre == "RPG"
    assert entry.description == "Monster hunter"
    assert entry.main_time == Decimal("25.0")


async def test_app_details_come_from_one_batch_request(monkeypatch: pytest.MonkeyPatch) -> None:
    batches: list[list[int]] = []

    async def fake_get_store_items(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        batches.append(list(app_ids))
        return {
            620: SteamAppDetails(name="Portal 2", header_image="https://example.com/p2.jpg"),
            504230: SteamAppDetails(name="Celeste", header_image=None),
        }

    async def forbidden_get_app_details(app_id: int) -> SteamAppDetails | None:
        raise AssertionError("the store page must not be asked for apps the batch resolved")

    monkeypatch.setattr(steam_service, "get_store_items", fake_get_store_items)
    monkeypatch.setattr(steam_service, "get_app_details", forbidden_get_app_details)

    details = await steam_service._get_steam_app_details([620, 504230])

    assert batches == [[620, 504230]]
    assert details[620].name == "Portal 2"
    assert details[504230].name == "Celeste"


async def test_app_details_ask_the_store_page_for_apps_the_batch_missed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def fake_get_store_items(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    asked: list[int] = []

    async def fake_get_app_details(app_id: int) -> SteamAppDetails | None:
        asked.append(app_id)
        return SteamAppDetails(name="Old Game", header_image=None) if app_id == 10 else None

    monkeypatch.setattr(steam_service, "get_store_items", fake_get_store_items)
    monkeypatch.setattr(steam_service, "get_app_details", fake_get_app_details)

    details = await steam_service._get_steam_app_details([620, 10, 11])

    assert sorted(asked) == [10, 11]
    assert set(details) == {620, 10}
    assert details[10].name == "Old Game"


async def test_app_details_fall_back_to_the_store_page_when_the_batch_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def failing_get_store_items(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        raise httpx.ConnectTimeout("timed out")

    async def fake_get_app_details(app_id: int) -> SteamAppDetails | None:
        return SteamAppDetails(name=f"Game {app_id}", header_image=None)

    monkeypatch.setattr(steam_service, "get_store_items", failing_get_store_items)
    monkeypatch.setattr(steam_service, "get_app_details", fake_get_app_details)

    details = await steam_service._get_steam_app_details([1, 2])

    assert {app_id: detail.name for app_id, detail in details.items()} == {
        1: "Game 1",
        2: "Game 2",
    }


async def test_app_details_skip_an_app_when_every_lookup_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def failing_get_store_items(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        raise httpx.ConnectTimeout("timed out")

    async def failing_get_app_details(app_id: int) -> SteamAppDetails | None:
        raise httpx.ConnectTimeout("timed out")

    monkeypatch.setattr(steam_service, "get_store_items", failing_get_store_items)
    monkeypatch.setattr(steam_service, "get_app_details", failing_get_app_details)

    assert await steam_service._get_steam_app_details([1, 2]) == {}


async def test_import_wishlist_marks_the_entries_and_the_user_as_imported(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    assert user.steam_wishlist_imported_at is None

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)

    [entry] = await steam_service.import_wishlist(session, user, [SteamWishlistItem(appid=620)])

    assert entry.steam_wishlist_import is True
    refreshed = await user_repo.get_user_by_id(session, user.id)
    assert refreshed.steam_wishlist_imported_at is not None


async def test_import_wishlist_keeps_the_date_of_the_first_import(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {
            app_id: SteamAppDetails(name=f"Game {app_id}", header_image=None) for app_id in app_ids
        }

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)

    await steam_service.import_wishlist(session, user, [SteamWishlistItem(appid=1)])
    first = (await user_repo.get_user_by_id(session, user.id)).steam_wishlist_imported_at
    await asyncio.sleep(0.01)
    await steam_service.import_wishlist(session, user, [SteamWishlistItem(appid=2)])

    assert (await user_repo.get_user_by_id(session, user.id)).steam_wishlist_imported_at == first


async def test_games_imported_from_the_library_are_not_marked_as_wishlist_imports(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    entry = await _make_entry(session, user.id, steam_app_id=504230)

    assert entry.steam_wishlist_import is False


async def _make_broken_entry(
    session: AsyncSession, user_id: int, app_id: int, title: str
) -> object:
    return await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user_id,
            title=title,
            genre="",
            platform="PC",
            status="Not Owned",
            owned=False,
            interest=5,
            steam_app_id=app_id,
            image_link=None,
        ),
    )


async def test_repair_steam_titles_names_entries_that_carry_their_app_id(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    numeric = await _make_broken_entry(session, user.id, 620, "620")
    generic = await _make_broken_entry(session, user.id, 504230, "Steam App 504230")
    healthy = await _make_entry(session, user.id, title="Hades", steam_app_id=1145360)

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        assert sorted(app_ids) == [620, 504230]
        return {
            620: SteamAppDetails(name="Portal™ 2", header_image="https://example.com/p2.jpg"),
            504230: SteamAppDetails(name="Celeste", header_image=None),
        }

    async def fake_cover(app_id: int, key: str | None) -> str | None:
        return "https://example.com/grid.jpg" if app_id == 504230 else None

    async def fake_search(title: str, *args: object, **kwargs: object) -> list[EnrichedResult]:
        return [_igdb_result(genres=["Puzzle"], description="Think with portals")]

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", fake_cover)
    monkeypatch.setattr(steam_service.game_service, "search", fake_search)

    repairs = await steam_service.repair_steam_titles(
        session, user, igdb_credentials=("cid", "secret")
    )

    assert {(r.steam_app_id, r.old_title, r.new_title) for r in repairs} == {
        (620, "620", "Portal 2"),
        (504230, "Steam App 504230", "Celeste"),
    }
    entries = {
        entry.steam_app_id: entry
        for entry in await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    }
    assert entries[620].title == "Portal 2"
    assert entries[620].genre == "Puzzle"
    assert entries[620].description == "Think with portals"
    assert entries[620].image_link == "https://example.com/p2.jpg"
    assert entries[504230].image_link == "https://example.com/grid.jpg"
    assert entries[620].steam_wishlist_import is True
    assert entries[1145360].title == "Hades"
    assert entries[1145360].steam_wishlist_import is False
    assert numeric.backlog_entry_id == entries[620].backlog_entry_id
    assert generic.backlog_entry_id == entries[504230].backlog_entry_id
    assert healthy.backlog_entry_id == entries[1145360].backlog_entry_id
    refreshed = await user_repo.get_user_by_id(session, user.id)
    assert refreshed.steam_wishlist_imported_at is not None


async def test_repair_steam_titles_leaves_entries_the_store_cannot_name(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_broken_entry(session, user.id, 999, "999")

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {}

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)

    repairs = await steam_service.repair_steam_titles(session, user)

    assert [(r.steam_app_id, r.new_title) for r in repairs] == [(999, None)]
    [entry] = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    assert entry.title == "999"


async def test_repair_steam_titles_dry_run_only_reports(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_broken_entry(session, user.id, 620, "620")

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)

    repairs = await steam_service.repair_steam_titles(session, user, dry_run=True)

    assert [(r.old_title, r.new_title) for r in repairs] == [("620", "Portal 2")]
    [entry] = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    assert entry.title == "620"
    assert entry.steam_wishlist_import is False
    assert (await user_repo.get_user_by_id(session, user.id)).steam_wishlist_imported_at is None


async def test_repair_steam_titles_does_nothing_without_broken_entries(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Hades", steam_app_id=1145360)

    async def forbidden(app_ids: list[int], budget: object = None) -> dict[int, SteamAppDetails]:
        raise AssertionError("nothing to look up")

    monkeypatch.setattr(steam_service, "_get_steam_app_details", forbidden)

    assert await steam_service.repair_steam_titles(session, user) == []


async def test_preview_wishlist_leaves_out_games_the_store_cannot_name(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_wishlist(steam_id: str) -> list[SteamWishlistItem]:
        return [SteamWishlistItem(appid=620), SteamWishlistItem(appid=999)]

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "get_wishlist", fake_get_wishlist)
    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)

    preview = await steam_service.preview_wishlist(session, user)

    assert [(item.steam_app_id, item.title) for item in preview] == [(620, "Portal 2")]


async def test_import_wishlist_skips_games_without_a_name_instead_of_using_the_app_id(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)

    created = await steam_service.import_wishlist(
        session, user, [SteamWishlistItem(appid=620), SteamWishlistItem(appid=999)]
    )

    assert [entry.title for entry in created] == ["Portal 2"]
    titles = [
        e.title for e in await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    ]
    assert titles == ["Portal 2"]


async def test_import_wishlist_stays_open_for_a_retry_when_a_game_was_skipped(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)

    await steam_service.import_wishlist(
        session, user, [SteamWishlistItem(appid=620), SteamWishlistItem(appid=999)]
    )

    assert (await user_repo.get_user_by_id(session, user.id)).steam_wishlist_imported_at is None


async def test_the_retry_after_a_skipped_game_imports_it_and_marks_the_import(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    names: dict[int, SteamAppDetails] = {620: SteamAppDetails(name="Portal 2", header_image=None)}

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        return {app_id: names[app_id] for app_id in app_ids if app_id in names}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    items = [SteamWishlistItem(appid=620), SteamWishlistItem(appid=999)]
    await steam_service.import_wishlist(session, user, items)

    names[999] = SteamAppDetails(name="Hades", header_image=None)
    created = await steam_service.import_wishlist(session, user, items)

    assert [entry.title for entry in created] == ["Hades"]
    assert (await user_repo.get_user_by_id(session, user.id)).steam_wishlist_imported_at is not None


async def test_names_that_were_resolved_before_are_not_looked_up_again(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.repositories import steam_app_cache_repo

    await steam_app_cache_repo.upsert_many(session, {620: SteamAppDetails(name="Portal 2")})
    asked: list[list[int]] = []

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        asked.append(list(app_ids))
        return {app_id: SteamAppDetails(name=f"Game {app_id}") for app_id in app_ids}

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)

    details = await steam_service._resolve_app_details(session, [620, 10, 10])

    assert asked == [[10]]
    assert details[620].name == "Portal 2"
    assert details[10].name == "Game 10"


async def test_resolved_names_are_stored_for_the_next_lookup(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = 0

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        nonlocal calls
        calls += 1
        return {
            app_id: SteamAppDetails(name=f"Game {app_id}") for app_id in app_ids if app_id != 99
        }

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)

    await steam_service._resolve_app_details(session, [10, 99])
    again = await steam_service._resolve_app_details(session, [10, 99])

    assert calls == 2
    assert set(again) == {10}


async def test_nothing_is_asked_when_every_name_is_stored(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.repositories import steam_app_cache_repo

    await steam_app_cache_repo.upsert_many(session, {620: SteamAppDetails(name="Portal 2")})

    async def forbidden(app_ids: list[int], budget: object = None) -> dict[int, SteamAppDetails]:
        raise AssertionError("every name is stored")

    monkeypatch.setattr(steam_service, "_get_steam_app_details", forbidden)

    assert (await steam_service._resolve_app_details(session, [620]))[620].name == "Portal 2"


async def test_a_second_users_wishlist_import_reuses_the_stored_names(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    asked: list[list[int]] = []

    async def fake_get_steam_app_details(
        app_ids: list[int], budget: object = None
    ) -> dict[int, SteamAppDetails]:
        asked.append(list(app_ids))
        return {app_id: SteamAppDetails(name=f"Game {app_id}") for app_id in app_ids}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    first = await _make_user(session)
    second = await user_repo.create_user(
        session,
        CreateUserParams(
            username="second", email="second@example.com", password_hash="h", steam_id="2"
        ),
    )

    await steam_service.import_wishlist(session, first, [SteamWishlistItem(appid=620)])
    created = await steam_service.import_wishlist(session, second, [SteamWishlistItem(appid=620)])

    assert asked == [[620]]
    assert [entry.title for entry in created] == ["Game 620"]

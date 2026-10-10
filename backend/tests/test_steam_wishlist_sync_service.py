from datetime import UTC, datetime

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import SteamAppDetails, SteamWishlistItem
from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import (
    CreateBacklogEntryParams,
    UpdateBacklogEntryParams,
)
from backlog_manager_backend.schemas.steam_wishlist_sync import (
    SteamWishlistChange,
    SteamWishlistSyncReport,
)
from backlog_manager_backend.schemas.user import CreateUserParams, UpdateUserParams
from backlog_manager_backend.services import steam_service, steam_wishlist_sync_service

NOW = datetime(2026, 10, 10, 12, 0, tzinfo=UTC)


def _change(app_id: int, title: str = "Game") -> SteamWishlistChange:
    return SteamWishlistChange(steam_app_id=app_id, title=title)


def test_merge_report_records_the_first_changes_with_their_time() -> None:
    report = steam_wishlist_sync_service.merge_report(
        None, [_change(1, "One")], [_change(2, "Two")], NOW
    )

    assert report.since == NOW
    assert [c.steam_app_id for c in report.added] == [1]
    assert [c.steam_app_id for c in report.removed] == [2]


def test_merge_report_keeps_the_time_of_the_first_change() -> None:
    first = steam_wishlist_sync_service.merge_report(None, [_change(1)], [], NOW)
    later = datetime(2026, 10, 11, tzinfo=UTC)

    second = steam_wishlist_sync_service.merge_report(first, [_change(2)], [], later)

    assert second.since == NOW
    assert [c.steam_app_id for c in second.added] == [1, 2]


def test_merge_report_cancels_a_removal_followed_by_an_add() -> None:
    first = steam_wishlist_sync_service.merge_report(None, [], [_change(1)], NOW)

    second = steam_wishlist_sync_service.merge_report(first, [_change(1)], [], NOW)

    assert second is None


def test_merge_report_cancels_an_add_followed_by_a_removal() -> None:
    first = steam_wishlist_sync_service.merge_report(None, [_change(1)], [], NOW)

    second = steam_wishlist_sync_service.merge_report(first, [], [_change(1)], NOW)

    assert second is None


def test_merge_report_ignores_nothing_to_report() -> None:
    assert steam_wishlist_sync_service.merge_report(None, [], [], NOW) is None
    existing = SteamWishlistSyncReport(since=NOW, added=[_change(1)])
    assert steam_wishlist_sync_service.merge_report(existing, [], [], NOW) == existing


@pytest.fixture(autouse=True)
def _offline(monkeypatch: pytest.MonkeyPatch) -> None:
    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    async def no_match(title: str, credentials: object) -> None:
        return None

    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)
    monkeypatch.setattr(steam_service.game_service, "find_igdb_match", no_match)


def _wishlist(monkeypatch: pytest.MonkeyPatch, *app_ids: int) -> None:
    async def fake_get_wishlist(steam_id: str) -> list[SteamWishlistItem]:
        return [SteamWishlistItem(appid=app_id) for app_id in app_ids]

    async def fake_details(app_ids: list[int], budget: object = None) -> dict[int, SteamAppDetails]:
        return {app_id: SteamAppDetails(name=f"Game {app_id}") for app_id in app_ids}

    monkeypatch.setattr(steam_service, "get_wishlist", fake_get_wishlist)
    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_details)


async def _user(session: AsyncSession, name: str = "syncer", **fields: object):
    user = await user_repo.create_user(
        session,
        CreateUserParams(
            username=name,
            email=f"{name}@example.com",
            password_hash="h",
            steam_id="76561197960287930",
        ),
    )
    return await user_repo.update_user(
        session,
        UpdateUserParams(
            user_id=user.id,
            steam_wishlist_auto_sync=True,
            **fields,
        ),
    )


async def _entry(
    session: AsyncSession,
    user_id: int,
    app_id: int,
    *,
    wishlist: bool = True,
    status: str = "Not Owned",
    owned: bool = False,
):
    return await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user_id,
            title=f"Game {app_id}",
            genre="",
            platform="PC",
            status=status,
            owned=owned,
            interest=5,
            steam_app_id=app_id,
            steam_wishlist_import=wishlist,
        ),
    )


async def _titles(session: AsyncSession, user_id: int) -> set[str]:
    return {e.title for e in await backlog_entry_repo.get_backlog_entries_by_user(session, user_id)}


async def test_sync_adds_new_wishlist_games_and_reports_them(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _user(session)
    await _entry(session, user.id, 10)
    _wishlist(monkeypatch, 10, 20)

    result = await steam_wishlist_sync_service.sync_user(session, user)

    assert (result.added, result.removed) == (1, 0)
    assert await _titles(session, user.id) == {"Game 10", "Game 20"}
    refreshed = await user_repo.get_user_by_id(session, user.id)
    assert [c.title for c in refreshed.steam_wishlist_sync_report.added] == ["Game 20"]
    created = [
        e
        for e in await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
        if e.steam_app_id == 20
    ]
    assert created[0].steam_wishlist_import is True


async def test_sync_removes_games_that_left_the_wishlist_and_reports_them(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _user(session)
    await _entry(session, user.id, 10)
    await _entry(session, user.id, 20)
    _wishlist(monkeypatch, 10)

    result = await steam_wishlist_sync_service.sync_user(session, user)

    assert (result.added, result.removed) == (0, 1)
    assert await _titles(session, user.id) == {"Game 10"}
    refreshed = await user_repo.get_user_by_id(session, user.id)
    assert [c.title for c in refreshed.steam_wishlist_sync_report.removed] == ["Game 20"]


async def test_sync_never_touches_entries_that_did_not_come_from_the_wishlist(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _user(session)
    await _entry(session, user.id, 10)
    await _entry(session, user.id, 30, wishlist=False, status="Playing", owned=True)
    _wishlist(monkeypatch, 10)

    result = await steam_wishlist_sync_service.sync_user(session, user)

    assert (result.added, result.removed) == (0, 0)
    assert await _titles(session, user.id) == {"Game 10", "Game 30"}


async def test_sync_keeps_a_wishlist_game_the_user_has_worked_with(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _user(session)
    bought = await _entry(session, user.id, 20)
    await backlog_entry_repo.update_backlog_entry(
        session,
        UpdateBacklogEntryParams(
            backlog_entry_id=bought.backlog_entry_id, status="Playing", owned=True
        ),
    )
    _wishlist(monkeypatch, 10)

    result = await steam_wishlist_sync_service.sync_user(session, user)

    assert result.removed == 0
    entry = await backlog_entry_repo.get_backlog_entry_by_id(session, bought.backlog_entry_id)
    assert entry.steam_wishlist_import is False
    refreshed = await user_repo.get_user_by_id(session, user.id)
    assert [c.steam_app_id for c in refreshed.steam_wishlist_sync_report.added] == [10]
    assert refreshed.steam_wishlist_sync_report.removed == []


async def test_sync_treats_an_empty_wishlist_as_unreadable_and_removes_nothing(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _user(session)
    await _entry(session, user.id, 10)
    _wishlist(monkeypatch)

    result = await steam_wishlist_sync_service.sync_user(session, user)

    assert (result.added, result.removed) == (0, 0)
    assert await _titles(session, user.id) == {"Game 10"}


async def test_sync_collects_the_changes_of_several_runs_in_one_report(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _user(session)
    await _entry(session, user.id, 10)
    _wishlist(monkeypatch, 10, 20)
    await steam_wishlist_sync_service.sync_user(session, user)
    user = await user_repo.get_user_by_id(session, user.id)
    _wishlist(monkeypatch, 10, 30)

    await steam_wishlist_sync_service.sync_user(session, user)

    refreshed = await user_repo.get_user_by_id(session, user.id)
    assert [c.steam_app_id for c in refreshed.steam_wishlist_sync_report.added] == [30]
    assert refreshed.steam_wishlist_sync_report.removed == []


async def test_sync_heals_entries_that_still_carry_the_app_id_as_title(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _user(session)
    broken = await _entry(session, user.id, 10)
    await backlog_entry_repo.update_backlog_entry(
        session, UpdateBacklogEntryParams(backlog_entry_id=broken.backlog_entry_id, title="10")
    )
    _wishlist(monkeypatch, 10)

    await steam_wishlist_sync_service.sync_user(session, user)

    assert await _titles(session, user.id) == {"Game 10"}


async def test_sync_all_only_serves_users_who_opted_in_after_the_first_import(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    ready = await _user(session, "ready")
    await user_repo.mark_steam_wishlist_imported(session, ready.id)
    not_imported = await _user(session, "notimported")
    opted_out = await _user(session, "optedout")
    await user_repo.mark_steam_wishlist_imported(session, opted_out.id)
    await user_repo.update_user(
        session, UpdateUserParams(user_id=opted_out.id, steam_wishlist_auto_sync=False)
    )
    _wishlist(monkeypatch, 10)

    summary = await steam_wishlist_sync_service.sync_all(session)

    assert (summary.users, summary.added, summary.failed) == (1, 1, 0)
    assert await _titles(session, ready.id) == {"Game 10"}
    assert await _titles(session, not_imported.id) == set()
    assert await _titles(session, opted_out.id) == set()


async def test_sync_all_goes_on_after_a_user_fails(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    first = await _user(session, "first")
    second = await _user(session, "second")
    for user in (first, second):
        await user_repo.mark_steam_wishlist_imported(session, user.id)
    _wishlist(monkeypatch, 10)
    real = steam_service.get_wishlist
    calls = 0

    async def flaky(steam_id: str) -> list[SteamWishlistItem]:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise RuntimeError("steam down")
        return await real(steam_id)

    monkeypatch.setattr(steam_service, "get_wishlist", flaky)

    summary = await steam_wishlist_sync_service.sync_all(session)

    assert (summary.users, summary.failed, summary.added) == (1, 1, 1)

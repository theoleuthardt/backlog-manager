import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.csv import parse_csv
from backlog_manager_backend.integrations.types import HltbResultData
from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.user import CreateUserParams

_COLUMN_CONFIG = parse_csv.ColumnConfig(
    title_column="A", genre_column="B", platform_column="C", status_column="D"
)


async def _make_user(session: AsyncSession) -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username="csvowner", email="csvowner@example.com", password_hash="h"),
    )


def _hltb_result(title: str) -> HltbResultData:
    return HltbResultData(
        id=1,
        hltb_id=1,
        title=title,
        image_url="https://example.com/cover.jpg",
        main_story=8.5,
        main_story_with_extras=12.0,
        completionist=37.0,
        last_updated_at="2024-01-01",
    )


def test_parse_csv_content_splits_columns_into_letter_keys() -> None:
    records = parse_csv.parse_csv_content(
        "Celeste,Platformer,PC,Not Started\nHades,Roguelike,PC,Completed"
    )

    assert records == [
        {"A": "Celeste", "B": "Platformer", "C": "PC", "D": "Not Started"},
        {"A": "Hades", "B": "Roguelike", "C": "PC", "D": "Completed"},
    ]


def test_parse_csv_content_skips_empty_lines() -> None:
    records = parse_csv.parse_csv_content(
        "Celeste,Platformer,PC,Not Started\n\n\nHades,Roguelike,PC,Completed"
    )

    assert len(records) == 2


async def test_import_creates_entry_when_found_on_hltb(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(parse_csv, "search_game_on_hltb", fake_search)

    result = await parse_csv.import_backlog_entries_from_csv(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "PC", "D": "Not Started"}],
        _COLUMN_CONFIG,
    )

    assert result.success == 1
    assert result.failed == 0
    assert result.missing_games == []

    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    assert len(entries) == 1
    assert entries[0].title == "Celeste"
    assert entries[0].image_link == "https://example.com/cover.jpg"
    assert entries[0].main_time == 8.5


async def test_import_tracks_missing_game_when_not_found_on_hltb(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_search(title: str) -> list[HltbResultData]:
        return []

    monkeypatch.setattr(parse_csv, "search_game_on_hltb", fake_search)

    result = await parse_csv.import_backlog_entries_from_csv(
        session,
        user.id,
        [{"A": "Unknown Game", "B": "RPG", "C": "PC", "D": "Not Started"}],
        _COLUMN_CONFIG,
    )

    assert result.success == 0
    assert result.failed == 0
    assert len(result.missing_games) == 1
    assert result.missing_games[0].title == "Unknown Game"

    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    assert entries == []


async def test_import_requires_title(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    monkeypatch.setattr(parse_csv, "search_game_on_hltb", lambda title: pytest.fail("unreachable"))

    result = await parse_csv.import_backlog_entries_from_csv(
        session,
        user.id,
        [{"A": "", "B": "RPG", "C": "PC", "D": "Not Started"}],
        _COLUMN_CONFIG,
    )

    assert result.failed == 1
    assert result.errors[0].error == "Title (column A) is required"


async def test_import_respects_cancel_flag(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(parse_csv, "search_game_on_hltb", fake_search)
    session_id = "cancel-test"
    parse_csv.set_cancel_flag(session_id, True)

    try:
        result = await parse_csv.import_backlog_entries_from_csv(
            session,
            user.id,
            [{"A": "Celeste", "B": "Platformer", "C": "PC", "D": "Not Started"}],
            _COLUMN_CONFIG,
            session_id=session_id,
        )
    finally:
        parse_csv.clear_import_progress(session_id)

    assert result.success == 0
    assert result.failed == 0


async def test_import_does_not_create_entry_if_cancelled_during_hltb_lookup(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    session_id = "cancel-mid-lookup-test"

    async def fake_search(title: str) -> list[HltbResultData]:
        # Simulates cancellation arriving while the HLTB request is in flight,
        # i.e. after this record's lookup has already started.
        parse_csv.set_cancel_flag(session_id, True)
        return [_hltb_result(title)]

    monkeypatch.setattr(parse_csv, "search_game_on_hltb", fake_search)

    try:
        result = await parse_csv.import_backlog_entries_from_csv(
            session,
            user.id,
            [{"A": "Celeste", "B": "Platformer", "C": "PC", "D": "Not Started"}],
            _COLUMN_CONFIG,
            session_id=session_id,
        )
    finally:
        parse_csv.clear_import_progress(session_id)

    assert result.success == 0
    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    assert entries == []


async def test_import_does_not_track_missing_game_if_cancelled_during_empty_hltb_lookup(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    session_id = "cancel-empty-lookup-test"

    async def fake_search(title: str) -> list[HltbResultData]:
        parse_csv.set_cancel_flag(session_id, True)
        return []

    monkeypatch.setattr(parse_csv, "search_game_on_hltb", fake_search)

    try:
        result = await parse_csv.import_backlog_entries_from_csv(
            session,
            user.id,
            [{"A": "Unknown Game", "B": "RPG", "C": "PC", "D": "Not Started"}],
            _COLUMN_CONFIG,
            session_id=session_id,
        )
    finally:
        parse_csv.clear_import_progress(session_id)

    assert result.success == 0
    assert result.missing_games == []


def test_import_progress_tracking() -> None:
    session_id = "progress-test"
    assert parse_csv.get_import_progress(session_id) == 0

    parse_csv.set_import_progress(session_id, 3)
    assert parse_csv.get_import_progress(session_id) == 3

    parse_csv.clear_import_progress(session_id)
    assert parse_csv.get_import_progress(session_id) == 0
    assert parse_csv.get_cancel_flag(session_id) is False

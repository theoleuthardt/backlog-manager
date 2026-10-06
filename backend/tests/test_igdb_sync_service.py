from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import EnrichedResult
from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.user import CreateUserParams
from backlog_manager_backend.services import game_service, igdb_sync_service


async def _make_user(session: AsyncSession) -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username="igdbuser", email="igdb@example.com", password_hash="h"),
    )


async def _make_entry(session: AsyncSession, user_id: int, **overrides: object) -> object:
    params: dict[str, object] = {
        "user_id": user_id,
        "title": "Celeste",
        "genre": "",
        "platform": "PC",
        "status": "Not Started",
        "owned": True,
        "interest": 5,
    }
    params.update(overrides)
    return await backlog_entry_repo.create_backlog_entry(
        session, CreateBacklogEntryParams(**params)
    )


def _match(**overrides: object) -> EnrichedResult:
    fields: dict[str, object] = {
        "id": 1,
        "hltb_id": 1,
        "title": "Celeste",
        "image_url": None,
        "genres": ["Platformer"],
        "platforms": [],
        "main_story": 8.0,
        "main_story_with_extras": 12.0,
        "completionist": 30.0,
        "description": "Climb a mountain",
        "trailer_url": "https://www.youtube.com/watch?v=trailer0001",
        "publisher": "Maddy Makes Games",
    }
    fields.update(overrides)
    return EnrichedResult(**fields)


@pytest.fixture
def searched(monkeypatch: pytest.MonkeyPatch) -> list[str]:
    titles: list[str] = []

    async def fake_search(title: str, *args: object, **kwargs: object) -> list[EnrichedResult]:
        titles.append(title)
        return [_match()]

    monkeypatch.setattr(game_service, "search", fake_search)
    return titles


async def test_sync_fills_missing_igdb_fields(session: AsyncSession, searched: list[str]) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id)

    [updated] = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert searched == ["Celeste"]
    assert updated.genre == "Platformer"
    assert updated.description == "Climb a mountain"
    assert updated.trailer_link == "https://www.youtube.com/watch?v=trailer0001"
    assert updated.main_time == Decimal("8.0")
    assert updated.completion_time == Decimal("30.0")


async def test_sync_never_overwrites_existing_values(
    session: AsyncSession, searched: list[str]
) -> None:
    user = await _make_user(session)
    await _make_entry(
        session,
        user.id,
        genre="Indie",
        description="My own words",
        publisher="My Label",
        trailer_link="https://www.youtube.com/watch?v=mine0000001",
        main_time=Decimal("1.0"),
    )
    entry = await _make_entry(session, user.id, title="Other", genre="Indie")

    updated = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert [e.backlog_entry_id for e in updated] == [entry.backlog_entry_id]
    assert updated[0].genre == "Indie"
    assert updated[0].description == "Climb a mountain"
    assert searched == ["Other"]


async def test_sync_searches_with_the_cleaned_title_and_stores_it_for_steam_entries(
    session: AsyncSession, searched: list[str]
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Celeste™", steam_app_id=504230)

    [updated] = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert searched == ["Celeste"]
    assert updated.title == "Celeste"


async def test_sync_cleans_titles_without_an_igdb_lookup_when_nothing_else_is_missing(
    session: AsyncSession, searched: list[str]
) -> None:
    user = await _make_user(session)
    await _make_entry(
        session,
        user.id,
        title="Hades®",
        genre="Roguelike",
        description="Escape",
        publisher="P",
        steam_app_id=1,
    )

    [updated] = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert searched == []
    assert updated.title == "Hades"


async def test_sync_keeps_entries_without_a_match_unchanged(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id)

    async def failing_search(*args: object, **kwargs: object) -> list[EnrichedResult]:
        raise httpx.ConnectError("boom")

    monkeypatch.setattr(game_service, "search", failing_search)

    assert await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret")) == []


async def test_sync_reports_progress_for_every_candidate(
    session: AsyncSession, searched: list[str]
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="One")
    await _make_entry(session, user.id, title="Two")
    await _make_entry(session, user.id, title="Done", genre="X", description="Y", publisher="P")
    progress: list[tuple[int, int]] = []

    async def on_progress(processed: int, total: int) -> None:
        progress.append((processed, total))

    await igdb_sync_service.sync_igdb_data(
        session, user, ("cid", "secret"), on_progress=on_progress
    )

    assert sorted(progress) == [(1, 2), (2, 2)]


async def test_count_matches_the_entries_the_sync_would_handle(
    session: AsyncSession, searched: list[str]
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Needs data")
    await _make_entry(session, user.id, title="Done", genre="X", description="Y", publisher="P")
    await _make_entry(
        session, user.id, title="Dirty™", genre="X", description="Y", publisher="P", steam_app_id=7
    )
    await _make_entry(session, user.id, title="Manual™", genre="X", description="Y", publisher="P")

    assert await igdb_sync_service.count_entries_needing_sync(session, user.id) == 2


async def test_sync_fills_a_missing_publisher(
    session: AsyncSession, searched: list[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, genre="Platformer", description="Already described")
    requested: dict[str, object] = {}

    async def fake_search(title: str, *args: object, **kwargs: object) -> list[EnrichedResult]:
        requested.update(kwargs)
        return [_match()]

    monkeypatch.setattr(game_service, "search", fake_search)

    [updated] = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert requested["include_publisher"] is True
    assert updated.publisher == "Maddy Makes Games"


async def test_sync_never_overwrites_a_publisher_the_user_set(
    session: AsyncSession, searched: list[str]
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, publisher="My Own Label")

    [updated] = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert updated.publisher == "My Own Label"
    assert updated.genre == "Platformer"


async def test_sync_marks_a_game_without_a_publisher_as_looked_up(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, genre="Platformer", description="Already described")

    async def fake_search(title: str, *args: object, **kwargs: object) -> list[EnrichedResult]:
        return [_match(publisher=None)]

    monkeypatch.setattr(game_service, "search", fake_search)

    [updated] = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert updated.publisher == ""
    assert await igdb_sync_service.count_entries_needing_sync(session, user.id) == 0


async def test_sync_cuts_an_oversized_publisher_to_the_column_length(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, genre="Platformer", description="Already described")

    async def fake_search(title: str, *args: object, **kwargs: object) -> list[EnrichedResult]:
        return [_match(publisher="p" * 300)]

    monkeypatch.setattr(game_service, "search", fake_search)

    [updated] = await igdb_sync_service.sync_igdb_data(session, user, ("cid", "secret"))

    assert updated.publisher == "p" * 255

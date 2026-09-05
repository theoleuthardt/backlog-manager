import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.repositories import (
    backlog_entry_repo,
    category_backlog_entry_repo,
    category_repo,
    user_repo,
)
from backlog_manager_backend.schemas.backlog_entry import (
    CategoryBacklogAssociationParams,
    CreateBacklogEntryParams,
    GetEntriesByStatusParams,
    UpdateBacklogEntryParams,
)
from backlog_manager_backend.schemas.category import CreateCategoryParams
from backlog_manager_backend.schemas.user import CreateUserParams


async def _make_user(session: AsyncSession) -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username="entryowner", email="entryowner@example.com", password_hash="h"),
    )


async def _make_entry(session: AsyncSession, user_id: int, **overrides: object) -> object:
    params = CreateBacklogEntryParams(
        user_id=user_id,
        title=overrides.get("title", "Elden Ring"),
        genre=overrides.get("genre", "RPG"),
        platform=overrides.get("platform", "PC"),
        status=overrides.get("status", "Not Started"),
        owned=overrides.get("owned", True),
        interest=overrides.get("interest", 8),
    )
    return await backlog_entry_repo.create_backlog_entry(session, params)


async def test_create_backlog_entry(session: AsyncSession) -> None:
    user = await _make_user(session)

    entry = await _make_entry(session, user.id)

    assert entry.title == "Elden Ring"
    assert entry.status == "Not Started"
    assert entry.completed_at is None


async def test_get_backlog_entries_by_user(session: AsyncSession) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Game A")
    await _make_entry(session, user.id, title="Game B")

    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)

    assert {e.title for e in entries} == {"Game A", "Game B"}


async def test_get_backlog_entry_by_id_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await backlog_entry_repo.get_backlog_entry_by_id(session, 999_999_999)


async def test_get_backlog_entries_by_status(session: AsyncSession) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Playing", status="In Progress")
    await _make_entry(session, user.id, title="Backlog", status="Not Started")

    entries = await backlog_entry_repo.get_backlog_entries_by_status(
        session, GetEntriesByStatusParams(user_id=user.id, status="In Progress")
    )

    assert [e.title for e in entries] == ["Playing"]


async def test_update_backlog_entry_to_completed_sets_completed_at(
    session: AsyncSession,
) -> None:
    """Confirms the DB trigger (update_completed_at) still fires
    transparently under the ORM - not something this repo implements."""
    user = await _make_user(session)
    entry = await _make_entry(session, user.id, status="In Progress")

    updated = await backlog_entry_repo.update_backlog_entry(
        session, UpdateBacklogEntryParams(backlog_entry_id=entry.backlog_entry_id, status="Completed")
    )

    assert updated.status == "Completed"
    assert updated.completed_at is not None


async def test_update_backlog_entry_away_from_completed_clears_completed_at(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    entry = await _make_entry(session, user.id, status="Completed")
    assert (await backlog_entry_repo.get_backlog_entry_by_id(
        session, entry.backlog_entry_id
    )).completed_at is None  # never was "In Progress" first, trigger only fires on UPDATE

    completed = await backlog_entry_repo.update_backlog_entry(
        session, UpdateBacklogEntryParams(backlog_entry_id=entry.backlog_entry_id, status="Dropped")
    )

    assert completed.status == "Dropped"
    assert completed.completed_at is None


async def test_update_backlog_entry_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await backlog_entry_repo.update_backlog_entry(
            session, UpdateBacklogEntryParams(backlog_entry_id=999_999_999, title="x")
        )


async def test_delete_backlog_entry(session: AsyncSession) -> None:
    user = await _make_user(session)
    entry = await _make_entry(session, user.id)

    await backlog_entry_repo.delete_backlog_entry(session, entry.backlog_entry_id)

    with pytest.raises(NotFoundError):
        await backlog_entry_repo.get_backlog_entry_by_id(session, entry.backlog_entry_id)


async def test_delete_backlog_entry_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await backlog_entry_repo.delete_backlog_entry(session, 999_999_999)


async def test_get_backlog_entries_for_category(session: AsyncSession) -> None:
    user = await _make_user(session)
    category = await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="Playing Now")
    )
    entry = await _make_entry(session, user.id)

    await category_backlog_entry_repo.add_category_to_backlog_entry(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=entry.backlog_entry_id
        ),
    )

    entries = await backlog_entry_repo.get_backlog_entries_for_category(
        session, category.category_id
    )

    assert [e.backlog_entry_id for e in entries] == [entry.backlog_entry_id]

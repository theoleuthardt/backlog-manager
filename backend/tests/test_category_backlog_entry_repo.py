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
)
from backlog_manager_backend.schemas.category import CreateCategoryParams
from backlog_manager_backend.schemas.user import CreateUserParams


async def _make_user_category_entry(session: AsyncSession) -> tuple[object, object, object]:
    user = await user_repo.create_user(
        session,
        CreateUserParams(username="assocowner", email="assocowner@example.com", password_hash="h"),
    )
    category = await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="Playing")
    )
    entry = await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user.id,
            title="Hollow Knight",
            genre="Metroidvania",
            platform="PC",
            status="Not Started",
            owned=True,
            interest=9,
        ),
    )
    return user, category, entry


async def test_add_category_to_backlog_entry(session: AsyncSession) -> None:
    _, category, entry = await _make_user_category_entry(session)

    assoc = await category_backlog_entry_repo.add_category_to_backlog_entry(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=entry.backlog_entry_id
        ),
    )

    assert assoc.category_id == category.category_id
    assert assoc.backlog_entry_id == entry.backlog_entry_id


async def test_remove_backlog_entry_from_category(session: AsyncSession) -> None:
    _, category, entry = await _make_user_category_entry(session)
    await category_backlog_entry_repo.add_category_to_backlog_entry(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=entry.backlog_entry_id
        ),
    )

    await category_backlog_entry_repo.remove_backlog_entry_from_category(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=entry.backlog_entry_id
        ),
    )

    entries = await backlog_entry_repo.get_backlog_entries_for_category(
        session, category.category_id
    )
    assert entries == []


async def test_remove_backlog_entry_from_category_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await category_backlog_entry_repo.remove_backlog_entry_from_category(
            session,
            CategoryBacklogAssociationParams(category_id=999_999_999, backlog_entry_id=999_999_999),
        )


async def test_delete_category_backlog_entries(session: AsyncSession) -> None:
    _, category, entry = await _make_user_category_entry(session)
    await category_backlog_entry_repo.add_category_to_backlog_entry(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=entry.backlog_entry_id
        ),
    )

    deleted = await category_backlog_entry_repo.delete_category_backlog_entries(
        session, category.category_id
    )

    assert [d.backlog_entry_id for d in deleted] == [entry.backlog_entry_id]
    assert (
        await backlog_entry_repo.get_backlog_entries_for_category(session, category.category_id)
        == []
    )

from decimal import Decimal

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


async def _make_user(session: AsyncSession, username: str = "entryowner") -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(
            username=username,
            email=f"{username}@example.com",
            password_hash="h",
        ),
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
        steam_app_id=overrides.get("steam_app_id"),
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


async def test_create_backlog_entry_with_playtime(session: AsyncSession) -> None:
    user = await _make_user(session)
    entry = await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user.id,
            title="Elden Ring",
            genre="RPG",
            platform="PC",
            status="In Progress",
            owned=True,
            interest=8,
            playtime=Decimal("12.5"),
        ),
    )

    assert entry.playtime == Decimal("12.5")


async def test_update_backlog_entry_playtime(session: AsyncSession) -> None:
    user = await _make_user(session)
    entry = await _make_entry(session, user.id)
    assert entry.playtime is None

    updated = await backlog_entry_repo.update_backlog_entry(
        session,
        UpdateBacklogEntryParams(
            backlog_entry_id=entry.backlog_entry_id, playtime=Decimal(30)
        ),
    )

    assert updated.playtime == Decimal(30)


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


async def test_update_backlog_entry_can_clear_nullable_field_with_explicit_none(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    entry = await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user.id,
            title="Elden Ring",
            genre="RPG",
            platform="PC",
            status="Completed",
            owned=True,
            interest=8,
            review_stars=5,
            note="loved it",
        ),
    )
    assert entry.review_stars == 5
    assert entry.note == "loved it"

    cleared = await backlog_entry_repo.update_backlog_entry(
        session,
        UpdateBacklogEntryParams(
            backlog_entry_id=entry.backlog_entry_id, review_stars=None, note=None
        ),
    )

    assert cleared.review_stars is None
    assert cleared.note is None
    # fields not mentioned in the update (left at UNSET) stay untouched
    assert cleared.title == "Elden Ring"


async def test_update_backlog_entry_omitted_fields_stay_unchanged(
    session: AsyncSession,
) -> None:
    """The bug this guards against: using a plain None default for every
    optional field made "not provided" and "explicitly cleared"
    indistinguishable, so a partial update calling anything other than
    the literal-provided fields would touch every column."""
    user = await _make_user(session)
    entry = await _make_entry(session, user.id, title="Original Title")

    updated = await backlog_entry_repo.update_backlog_entry(
        session, UpdateBacklogEntryParams(backlog_entry_id=entry.backlog_entry_id)
    )

    assert updated.title == "Original Title"
    assert updated.genre == entry.genre
    assert updated.status == entry.status


async def test_update_backlog_entry_away_from_completed_clears_completed_at(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    entry = await _make_entry(session, user.id, status="In Progress")

    completed = await backlog_entry_repo.update_backlog_entry(
        session,
        UpdateBacklogEntryParams(backlog_entry_id=entry.backlog_entry_id, status="Completed"),
    )
    assert completed.completed_at is not None

    dropped = await backlog_entry_repo.update_backlog_entry(
        session, UpdateBacklogEntryParams(backlog_entry_id=entry.backlog_entry_id, status="Dropped")
    )

    assert dropped.status == "Dropped"
    assert dropped.completed_at is None


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


async def test_delete_backlog_entries_by_user(session: AsyncSession) -> None:
    user = await _make_user(session)
    other = await _make_user(session, username="entryother")
    entry = await _make_entry(session, user.id, title="Mine")
    other_entry = await _make_entry(session, other.id, title="Theirs")
    category = await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="C")
    )
    await category_backlog_entry_repo.add_category_to_backlog_entry(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=entry.backlog_entry_id
        ),
    )

    deleted = await backlog_entry_repo.delete_backlog_entries_by_user(session, user.id)

    assert deleted == 1
    assert await backlog_entry_repo.get_backlog_entries_by_user(session, user.id) == []
    assert [
        e.backlog_entry_id for e in await backlog_entry_repo.get_backlog_entries_by_user(
            session, other.id
        )
    ] == [other_entry.backlog_entry_id]
    # the category association cascaded away with its entry
    assert await category_repo.get_categories_for_backlog_entry(
        session, entry.backlog_entry_id
    ) == []


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

async def test_get_backlog_entry_duplicates_matches_title_case_insensitive(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Elden Ring")

    duplicates = await backlog_entry_repo.get_backlog_entry_duplicates(
        session, user.id, title="ELDEN RING", steam_app_id=None
    )

    assert [d.backlog_entry_id for d in duplicates] != []

async def test_get_backlog_entry_duplicates_matches_steam_app_id(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    entry = await _make_entry(
        session, user.id, title="Totally Different Name", steam_app_id=1245620
    )

    duplicates = await backlog_entry_repo.get_backlog_entry_duplicates(
        session, user.id, title="Elden Ring", steam_app_id=1245620
    )

    assert [d.backlog_entry_id for d in duplicates] == [entry.backlog_entry_id]

async def test_get_backlog_entry_duplicates_ignores_other_users(
    session: AsyncSession,
) -> None:
    user = await _make_user(session, "dupeowner")
    other = await _make_user(session, "otheruser")
    await _make_entry(session, other.id, title="Elden Ring")

    duplicates = await backlog_entry_repo.get_backlog_entry_duplicates(
        session, user.id, title="Elden Ring", steam_app_id=None
    )

    assert duplicates == []

async def test_get_backlog_entry_duplicates_no_match_returns_empty(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, title="Elden Ring")

    duplicates = await backlog_entry_repo.get_backlog_entry_duplicates(
        session, user.id, title="Hollow Knight", steam_app_id=None
    )

    assert duplicates == []

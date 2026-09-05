import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.repositories import category_repo, user_repo
from backlog_manager_backend.schemas.category import CreateCategoryParams, UpdateCategoryParams
from backlog_manager_backend.schemas.user import CreateUserParams


async def _make_user(session: AsyncSession) -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username="catowner", email="catowner@example.com", password_hash="h"),
    )


async def test_create_category_uses_defaults(session: AsyncSession) -> None:
    user = await _make_user(session)

    category = await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="Backlog")
    )

    assert category.name == "Backlog"
    assert category.color == "#000000"
    assert category.description == "No description"


async def test_create_category_with_explicit_values(session: AsyncSession) -> None:
    user = await _make_user(session)

    category = await category_repo.create_category(
        session,
        CreateCategoryParams(
            user_id=user.id,
            category_name="Playing",
            color="#00ff00",
            description="Currently playing",
        ),
    )

    assert category.color == "#00ff00"
    assert category.description == "Currently playing"


async def test_get_categories_by_user(session: AsyncSession) -> None:
    user = await _make_user(session)
    await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="A")
    )
    await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="B")
    )

    categories = await category_repo.get_categories_by_user(session, user.id)

    assert {c.name for c in categories} == {"A", "B"}


async def test_update_category_partial(session: AsyncSession) -> None:
    user = await _make_user(session)
    category = await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="Original")
    )

    updated = await category_repo.update_category(
        session, UpdateCategoryParams(category_id=category.category_id, color="#123456")
    )

    assert updated.color == "#123456"
    assert updated.name == "Original"


async def test_update_category_can_clear_description_with_explicit_none(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    category = await category_repo.create_category(
        session,
        CreateCategoryParams(
            user_id=user.id, category_name="Games", description="Has a description"
        ),
    )

    updated = await category_repo.update_category(
        session, UpdateCategoryParams(category_id=category.category_id, description=None)
    )

    assert updated.description is None
    assert updated.name == "Games"  # omitted field stays untouched


async def test_update_category_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await category_repo.update_category(
            session, UpdateCategoryParams(category_id=999_999_999, color="#ffffff")
        )


async def test_delete_category(session: AsyncSession) -> None:
    user = await _make_user(session)
    category = await category_repo.create_category(
        session, CreateCategoryParams(user_id=user.id, category_name="ToDelete")
    )

    await category_repo.delete_category(session, category.category_id)

    assert await category_repo.get_categories_by_user(session, user.id) == []


async def test_delete_category_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await category_repo.delete_category(session, 999_999_999)

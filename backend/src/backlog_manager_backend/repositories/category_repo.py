from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, handle_database_error
from backlog_manager_backend.models.category import Category as CategoryModel
from backlog_manager_backend.models.category_backlog_entry import CategoryBacklogEntry
from backlog_manager_backend.schemas.category import (
    Category,
    CreateCategoryParams,
    UpdateCategoryParams,
)
from backlog_manager_backend.utils import now_truncated_to_minute


def _to_schema(model: CategoryModel) -> Category:
    return Category(
        category_id=model.id,
        user_id=model.user_id,
        name=model.name,
        color=model.color,
        description=model.description,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


async def create_category(session: AsyncSession, params: CreateCategoryParams) -> Category:
    model = CategoryModel(
        user_id=params.user_id,
        name=params.category_name,
        color=params.color,
        description=params.description,
    )
    session.add(model)
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "create_category")
    await session.refresh(model)
    return _to_schema(model)


async def get_categories_by_user(session: AsyncSession, user_id: int) -> list[Category]:
    result = await session.execute(
        select(CategoryModel).where(CategoryModel.user_id == user_id)
    )
    return [_to_schema(row) for row in result.scalars().all()]


async def get_categories_for_backlog_entry(
    session: AsyncSession, backlog_entry_id: int
) -> list[Category]:
    result = await session.execute(
        select(CategoryModel)
        .join(
            CategoryBacklogEntry,
            CategoryBacklogEntry.category_id == CategoryModel.id,
        )
        .where(CategoryBacklogEntry.backlog_entry_id == backlog_entry_id)
    )
    return [_to_schema(row) for row in result.scalars().all()]


async def update_category(session: AsyncSession, params: UpdateCategoryParams) -> Category:
    model = await session.get(CategoryModel, params.category_id)
    if model is None:
        raise NotFoundError("Category", params.category_id)

    if params.category_name is not None:
        model.name = params.category_name
    if params.color is not None:
        model.color = params.color
    if params.description is not None:
        model.description = params.description
    model.updated_at = now_truncated_to_minute()

    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "update_category")
    await session.refresh(model)
    return _to_schema(model)


async def delete_category(session: AsyncSession, category_id: int) -> Category:
    model = await session.get(CategoryModel, category_id)
    if model is None:
        raise NotFoundError("Category", category_id)

    schema = _to_schema(model)
    await session.delete(model)
    await session.commit()
    return schema

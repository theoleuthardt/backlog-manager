from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, handle_database_error
from backlog_manager_backend.models.category_backlog_entry import (
    CategoryBacklogEntry as CategoryBacklogEntryModel,
)
from backlog_manager_backend.schemas.backlog_entry import (
    CategoryBacklogAssociationParams,
    CategoryBacklogEntry,
)


def _to_schema(model: CategoryBacklogEntryModel) -> CategoryBacklogEntry:
    return CategoryBacklogEntry(
        category_id=model.category_id,
        backlog_entry_id=model.backlog_entry_id,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


async def add_category_to_backlog_entry(
    session: AsyncSession, params: CategoryBacklogAssociationParams
) -> CategoryBacklogEntry:
    model = CategoryBacklogEntryModel(
        category_id=params.category_id,
        backlog_entry_id=params.backlog_entry_id,
    )
    session.add(model)
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "add_category_to_backlog_entry")
    await session.refresh(model)
    return _to_schema(model)


async def remove_backlog_entry_from_category(
    session: AsyncSession, params: CategoryBacklogAssociationParams
) -> CategoryBacklogEntry:
    model = await session.get(
        CategoryBacklogEntryModel, (params.category_id, params.backlog_entry_id)
    )
    if model is None:
        raise NotFoundError(
            "CategoryBacklogAssociation",
            f"{params.category_id}-{params.backlog_entry_id}",
        )

    schema = _to_schema(model)
    await session.delete(model)
    await session.commit()
    return schema

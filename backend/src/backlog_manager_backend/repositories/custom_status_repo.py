from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, handle_database_error
from backlog_manager_backend.models.custom_status import CustomStatus as CustomStatusModel
from backlog_manager_backend.schemas.custom_status import (
    CreateCustomStatusParams,
    CustomStatus,
    UpdateCustomStatusParams,
)
from backlog_manager_backend.utils import now_truncated_to_minute


def _to_schema(model: CustomStatusModel) -> CustomStatus:
    return CustomStatus(
        status_id=model.id,
        user_id=model.user_id,
        name=model.name,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


async def create_custom_status(
    session: AsyncSession, params: CreateCustomStatusParams
) -> CustomStatus:
    model = CustomStatusModel(user_id=params.user_id, name=params.name)
    session.add(model)
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "create_custom_status")
    await session.refresh(model)
    return _to_schema(model)


async def get_custom_statuses_by_user(
    session: AsyncSession, user_id: int
) -> list[CustomStatus]:
    result = await session.execute(
        select(CustomStatusModel).where(CustomStatusModel.user_id == user_id)
    )
    return [_to_schema(row) for row in result.scalars().all()]


async def get_custom_status_by_id(
    session: AsyncSession, status_id: int
) -> CustomStatus:
    model = await session.get(CustomStatusModel, status_id)
    if model is None:
        raise NotFoundError("CustomStatus", status_id)
    return _to_schema(model)


async def update_custom_status(
    session: AsyncSession, params: UpdateCustomStatusParams
) -> CustomStatus:
    model = await session.get(CustomStatusModel, params.status_id)
    if model is None:
        raise NotFoundError("CustomStatus", params.status_id)

    model.name = params.name
    model.updated_at = now_truncated_to_minute()
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "update_custom_status")
    await session.refresh(model)
    return _to_schema(model)


async def delete_custom_status(session: AsyncSession, status_id: int) -> CustomStatus:
    model = await session.get(CustomStatusModel, status_id)
    if model is None:
        raise NotFoundError("CustomStatus", status_id)

    schema = _to_schema(model)
    await session.delete(model)
    await session.commit()
    return schema
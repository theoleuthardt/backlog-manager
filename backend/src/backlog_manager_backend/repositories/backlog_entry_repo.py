import msgspec
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, handle_database_error
from backlog_manager_backend.models.backlog_entry import BacklogEntry as BacklogEntryModel
from backlog_manager_backend.models.category_backlog_entry import CategoryBacklogEntry
from backlog_manager_backend.schemas.backlog_entry import (
    BacklogEntry,
    CreateBacklogEntryParams,
    GetEntriesByStatusParams,
    UpdateBacklogEntryParams,
)
from backlog_manager_backend.utils import now_truncated_to_minute


def _to_schema(model: BacklogEntryModel) -> BacklogEntry:
    return BacklogEntry(
        backlog_entry_id=model.id,
        user_id=model.user_id,
        title=model.title,
        genre=model.genre,
        platform=model.platform,
        status=model.status,
        owned=model.owned,
        interest=model.interest,
        created_at=model.created_at,
        updated_at=model.updated_at,
        release_date=model.release_date,
        image_link=model.image_link,
        main_time=model.main_time,
        main_plus_extra_time=model.main_plus_extra_time,
        completion_time=model.completion_time,
        playtime=model.playtime,
        review_stars=model.review_stars,
        review=model.review,
        note=model.note,
        completed_at=model.completed_at,
    )


async def create_backlog_entry(
    session: AsyncSession, params: CreateBacklogEntryParams
) -> BacklogEntry:
    model = BacklogEntryModel(
        user_id=params.user_id,
        title=params.title,
        genre=params.genre,
        platform=params.platform,
        status=params.status,
        owned=params.owned,
        interest=params.interest,
        release_date=params.release_date,
        image_link=params.image_link,
        main_time=params.main_time,
        main_plus_extra_time=params.main_plus_extra_time,
        completion_time=params.completion_time,
        playtime=params.playtime,
        review_stars=params.review_stars,
        review=params.review,
        note=params.note,
    )
    session.add(model)
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "create_backlog_entry")
    await session.refresh(model)
    return _to_schema(model)


async def get_backlog_entries_by_user(
    session: AsyncSession, user_id: int
) -> list[BacklogEntry]:
    result = await session.execute(
        select(BacklogEntryModel).where(BacklogEntryModel.user_id == user_id)
    )
    return [_to_schema(row) for row in result.scalars().all()]


async def get_backlog_entry_by_id(
    session: AsyncSession, backlog_entry_id: int
) -> BacklogEntry:
    model = await session.get(BacklogEntryModel, backlog_entry_id)
    if model is None:
        raise NotFoundError("BacklogEntry", backlog_entry_id)
    return _to_schema(model)


async def get_backlog_entries_by_status(
    session: AsyncSession, params: GetEntriesByStatusParams
) -> list[BacklogEntry]:
    result = await session.execute(
        select(BacklogEntryModel).where(
            BacklogEntryModel.user_id == params.user_id,
            BacklogEntryModel.status == params.status,
        )
    )
    return [_to_schema(row) for row in result.scalars().all()]


async def get_backlog_entries_for_category(
    session: AsyncSession, category_id: int
) -> list[BacklogEntry]:
    result = await session.execute(
        select(BacklogEntryModel)
        .join(
            CategoryBacklogEntry,
            CategoryBacklogEntry.backlog_entry_id == BacklogEntryModel.id,
        )
        .where(CategoryBacklogEntry.category_id == category_id)
    )
    return [_to_schema(row) for row in result.scalars().all()]


async def update_backlog_entry(
    session: AsyncSession, params: UpdateBacklogEntryParams
) -> BacklogEntry:
    model = await session.get(BacklogEntryModel, params.backlog_entry_id)
    if model is None:
        raise NotFoundError("BacklogEntry", params.backlog_entry_id)

    if params.title is not msgspec.UNSET:
        model.title = params.title
    if params.genre is not msgspec.UNSET:
        model.genre = params.genre
    if params.platform is not msgspec.UNSET:
        model.platform = params.platform
    if params.status is not msgspec.UNSET:
        model.status = params.status
    if params.owned is not msgspec.UNSET:
        model.owned = params.owned
    if params.interest is not msgspec.UNSET:
        model.interest = params.interest
    if params.release_date is not msgspec.UNSET:
        model.release_date = params.release_date
    if params.image_link is not msgspec.UNSET:
        model.image_link = params.image_link
    if params.main_time is not msgspec.UNSET:
        model.main_time = params.main_time
    if params.main_plus_extra_time is not msgspec.UNSET:
        model.main_plus_extra_time = params.main_plus_extra_time
    if params.completion_time is not msgspec.UNSET:
        model.completion_time = params.completion_time
    if params.playtime is not msgspec.UNSET:
        model.playtime = params.playtime
    if params.review_stars is not msgspec.UNSET:
        model.review_stars = params.review_stars
    if params.review is not msgspec.UNSET:
        model.review = params.review
    if params.note is not msgspec.UNSET:
        model.note = params.note
    model.updated_at = now_truncated_to_minute()

    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "update_backlog_entry")
    await session.refresh(model)
    return _to_schema(model)


async def delete_backlog_entry(
    session: AsyncSession, backlog_entry_id: int
) -> BacklogEntry:
    model = await session.get(BacklogEntryModel, backlog_entry_id)
    if model is None:
        raise NotFoundError("BacklogEntry", backlog_entry_id)

    schema = _to_schema(model)
    await session.delete(model)
    await session.commit()
    return schema

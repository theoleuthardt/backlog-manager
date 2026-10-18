import msgspec
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.models.entry_mod import EntryMod as EntryModModel
from backlog_manager_backend.schemas.entry_mod import EntryMod
from backlog_manager_backend.utils import now_truncated_to_minute


def _to_schema(model: EntryModModel) -> EntryMod:
    return EntryMod(
        mod_id=model.id,
        backlog_entry_id=model.backlog_entry_id,
        name=model.name,
        url=model.url,
    )


async def get_mods_by_entry(session: AsyncSession, backlog_entry_id: int) -> list[EntryMod]:
    result = await session.execute(
        select(EntryModModel)
        .where(EntryModModel.backlog_entry_id == backlog_entry_id)
        .order_by(EntryModModel.id)
    )
    return [_to_schema(row) for row in result.scalars().all()]


async def count_mods(session: AsyncSession, backlog_entry_id: int) -> int:
    return (
        await session.scalar(
            select(func.count()).where(EntryModModel.backlog_entry_id == backlog_entry_id)
        )
        or 0
    )


async def create_mod(
    session: AsyncSession, backlog_entry_id: int, name: str, url: str | None
) -> EntryMod:
    model = EntryModModel(backlog_entry_id=backlog_entry_id, name=name, url=url)
    session.add(model)
    await session.commit()
    await session.refresh(model)
    return _to_schema(model)


async def _get_model(session: AsyncSession, backlog_entry_id: int, mod_id: int) -> EntryModModel:
    """A mod is only found through the entry it belongs to."""
    model = await session.get(EntryModModel, mod_id)
    if model is None or model.backlog_entry_id != backlog_entry_id:
        raise NotFoundError("EntryMod", mod_id)
    return model


async def update_mod(
    session: AsyncSession,
    backlog_entry_id: int,
    mod_id: int,
    name: str | msgspec.UnsetType,
    url: str | None | msgspec.UnsetType,
) -> EntryMod:
    model = await _get_model(session, backlog_entry_id, mod_id)
    if name is not msgspec.UNSET:
        model.name = name
    if url is not msgspec.UNSET:
        model.url = url
    model.updated_at = now_truncated_to_minute()
    await session.commit()
    await session.refresh(model)
    return _to_schema(model)


async def delete_mod(session: AsyncSession, backlog_entry_id: int, mod_id: int) -> None:
    await _get_model(session, backlog_entry_id, mod_id)
    await session.execute(delete(EntryModModel).where(EntryModModel.id == mod_id))
    await session.commit()

import msgspec
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, ValidationError
from backlog_manager_backend.models.backlog_entry import BacklogEntry as BacklogEntryModel
from backlog_manager_backend.models.entry_mod import EntryMod as EntryModModel
from backlog_manager_backend.schemas.entry_mod import MAX_MODS_PER_ENTRY, EntryMod
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


async def create_mod(
    session: AsyncSession, backlog_entry_id: int, name: str, url: str | None
) -> EntryMod:
    """Adds a mod unless the entry already has MAX_MODS_PER_ENTRY of them
    (ValidationError). The entry row is locked while counting, so two members
    of a shared space adding at once cannot both pass the limit."""
    await session.execute(
        select(BacklogEntryModel.id)
        .where(BacklogEntryModel.id == backlog_entry_id)
        .with_for_update()
    )
    count = await session.scalar(
        select(func.count()).where(EntryModModel.backlog_entry_id == backlog_entry_id)
    )
    if (count or 0) >= MAX_MODS_PER_ENTRY:
        await session.rollback()
        raise ValidationError(f"An entry has at most {MAX_MODS_PER_ENTRY} mods")
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

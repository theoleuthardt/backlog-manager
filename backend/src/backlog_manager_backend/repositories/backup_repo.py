from collections.abc import Sequence

import msgspec
from sqlalchemy import delete, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, ValidationError, handle_database_error
from backlog_manager_backend.models.backlog_entry import BacklogEntry
from backlog_manager_backend.models.category import Category
from backlog_manager_backend.models.category_backlog_entry import CategoryBacklogEntry
from backlog_manager_backend.models.custom_status import CustomStatus
from backlog_manager_backend.models.entry_mod import EntryMod
from backlog_manager_backend.models.space import SpaceMember
from backlog_manager_backend.models.space_entry_member_data import SpaceEntryMemberData
from backlog_manager_backend.models.user_backup import UserBackup
from backlog_manager_backend.schemas.backup import (
    PAYLOAD_VERSION,
    BackupCategory,
    BackupCustomStatus,
    BackupEntry,
    BackupMod,
    BackupPayload,
    BackupSummary,
)
from backlog_manager_backend.schemas.space_backup import SpaceBackupMemberData

_ENTRY_FIELDS = [
    "title",
    "genre",
    "platform",
    "status",
    "owned",
    "interest",
    "created_at",
    "updated_at",
    "release_date",
    "image_link",
    "description",
    "trailer_link",
    "publisher",
    "main_time",
    "main_plus_extra_time",
    "completion_time",
    "playtime",
    "steam_app_id",
    "steam_wishlist_import",
    "review_stars",
    "review",
    "note",
    "completed_at",
]


def _scope(model: type, user_id: int, space_id: int | None) -> tuple:
    """The rows of one backlog: a user's personal rows (SpaceID IS NULL -
    shared space rows carry their creator's UserID but belong to two
    people) or, with `space_id`, every row of that space."""
    if space_id is None:
        return (model.user_id == user_id, model.space_id.is_(None))
    return (model.space_id == space_id,)


def _to_summary(model: UserBackup) -> BackupSummary:
    return BackupSummary(
        id=model.id,
        kind=model.kind,
        name=model.name,
        created_at=model.created_at,
        entry_count=model.entry_count,
        category_count=model.category_count,
    )


async def load_content(
    session: AsyncSession, user_id: int, space_id: int | None = None
) -> tuple[BackupPayload, dict[int, int]]:
    """Reads one backlog's whole content (see `_scope`) into a snapshot
    payload, ordered by id so the same content always serialises the same
    way. The second value maps the database id of every entry to its ref."""
    entry_models = (
        await session.scalars(
            select(BacklogEntry)
            .where(*_scope(BacklogEntry, user_id, space_id))
            .order_by(BacklogEntry.id)
        )
    ).all()
    refs = {model.id: position for position, model in enumerate(entry_models, start=1)}

    mod_models = (
        await session.scalars(
            select(EntryMod)
            .where(EntryMod.backlog_entry_id.in_(refs))
            .order_by(EntryMod.backlog_entry_id, EntryMod.id)
        )
    ).all()
    mods_by_entry: dict[int, list[BackupMod]] = {}
    for mod in mod_models:
        mods_by_entry.setdefault(mod.backlog_entry_id, []).append(
            BackupMod(
                name=mod.name, url=mod.url, created_at=mod.created_at, updated_at=mod.updated_at
            )
        )

    links = (
        await session.execute(
            select(CategoryBacklogEntry.category_id, CategoryBacklogEntry.backlog_entry_id)
            .join(Category, Category.id == CategoryBacklogEntry.category_id)
            .where(*_scope(Category, user_id, space_id))
        )
    ).all()
    refs_by_category: dict[int, list[int]] = {}
    for category_id, entry_id in links:
        refs_by_category.setdefault(category_id, []).append(refs[entry_id])

    category_models = (
        await session.scalars(
            select(Category).where(*_scope(Category, user_id, space_id)).order_by(Category.id)
        )
    ).all()
    status_models = (
        await session.scalars(
            select(CustomStatus)
            .where(*_scope(CustomStatus, user_id, space_id))
            .order_by(CustomStatus.id)
        )
    ).all()

    payload = BackupPayload(
        version=PAYLOAD_VERSION,
        entries=[
            BackupEntry(
                ref=refs[model.id],
                mods=mods_by_entry.get(model.id, []),
                **{field: getattr(model, field) for field in _ENTRY_FIELDS},
            )
            for model in entry_models
        ],
        categories=[
            BackupCategory(
                name=model.name,
                color=model.color,
                description=model.description,
                created_at=model.created_at,
                updated_at=model.updated_at,
                entry_refs=sorted(refs_by_category.get(model.id, [])),
            )
            for model in category_models
        ],
        custom_statuses=[
            BackupCustomStatus(
                name=model.name, created_at=model.created_at, updated_at=model.updated_at
            )
            for model in status_models
        ],
    )
    return payload, refs


async def load_user_content(session: AsyncSession, user_id: int) -> BackupPayload:
    """The user's whole personal backlog content as a snapshot payload."""
    payload, _ = await load_content(session, user_id)
    return payload


async def replace_content(
    session: AsyncSession,
    user_id: int,
    payload: BackupPayload,
    space_id: int | None = None,
    member_data: Sequence[SpaceBackupMemberData] = (),
) -> None:
    """Swaps one backlog's whole content (a user's personal backlog, or the
    space `space_id`, never both) for the payload in one transaction: any
    failure (a payload the database rejects, e.g. two entries sharing a
    Steam app id) rolls back to the untouched previous content. Rows are
    re-created with fresh ids - category links are rebuilt from the
    payload's refs, `user_id` becomes the creator of every row, and
    `member_data` (a space's per-member fields, by entry ref) is stored
    for the members that are still active."""
    try:
        await session.execute(delete(BacklogEntry).where(*_scope(BacklogEntry, user_id, space_id)))
        await session.execute(delete(Category).where(*_scope(Category, user_id, space_id)))
        await session.execute(delete(CustomStatus).where(*_scope(CustomStatus, user_id, space_id)))

        entry_models = {
            entry.ref: BacklogEntry(
                user_id=user_id,
                space_id=space_id,
                **{field: getattr(entry, field) for field in _ENTRY_FIELDS},
            )
            for entry in payload.entries
        }
        session.add_all(entry_models.values())
        await session.flush()

        session.add_all(
            EntryMod(
                backlog_entry_id=entry_models[entry.ref].id,
                name=mod.name,
                url=mod.url,
                created_at=mod.created_at,
                updated_at=mod.updated_at,
            )
            for entry in payload.entries
            for mod in entry.mods
        )

        for category in payload.categories:
            category_model = Category(
                user_id=user_id,
                space_id=space_id,
                name=category.name,
                color=category.color,
                description=category.description,
                created_at=category.created_at,
                updated_at=category.updated_at,
            )
            session.add(category_model)
            await session.flush()
            for ref in category.entry_refs:
                if ref not in entry_models:
                    raise ValidationError("Backup links a category to an unknown entry")
                session.add(
                    CategoryBacklogEntry(
                        category_id=category_model.id,
                        backlog_entry_id=entry_models[ref].id,
                    )
                )

        session.add_all(
            CustomStatus(
                user_id=user_id,
                space_id=space_id,
                name=status.name,
                created_at=status.created_at,
                updated_at=status.updated_at,
            )
            for status in payload.custom_statuses
        )
        if member_data:
            active = set(
                (
                    await session.scalars(
                        select(SpaceMember.user_id).where(
                            SpaceMember.space_id == space_id, SpaceMember.status == "active"
                        )
                    )
                ).all()
            )
            session.add_all(
                SpaceEntryMemberData(
                    backlog_entry_id=entry_models[row.ref].id,
                    user_id=row.user_id,
                    playtime=row.playtime,
                    review_stars=row.review_stars,
                    review=row.review,
                    owned=row.owned,
                )
                for row in member_data
                if row.user_id in active and row.ref in entry_models
            )
        await session.commit()
    except DBAPIError as error:
        await session.rollback()
        handle_database_error(error, "replace_content")
    except Exception:
        await session.rollback()
        raise


async def replace_user_content(session: AsyncSession, user_id: int, payload: BackupPayload) -> None:
    """Swaps the user's whole personal backlog content for the payload."""
    await replace_content(session, user_id, payload)


async def create_backup(
    session: AsyncSession, user_id: int, kind: str, content_hash: str, payload: BackupPayload
) -> BackupSummary:
    model = UserBackup(
        user_id=user_id,
        kind=kind,
        content_hash=content_hash,
        entry_count=len(payload.entries),
        category_count=len(payload.categories),
        payload=msgspec.to_builtins(payload),
    )
    session.add(model)
    await session.commit()
    await session.refresh(model)
    return _to_summary(model)


async def list_backups(session: AsyncSession, user_id: int) -> list[BackupSummary]:
    result = await session.scalars(
        select(UserBackup).where(UserBackup.user_id == user_id).order_by(UserBackup.id.desc())
    )
    return [_to_summary(model) for model in result.all()]


async def get_backup(session: AsyncSession, user_id: int, backup_id: int) -> UserBackup:
    """Scoped to the owner: another user's backup is indistinguishable
    from a missing one."""
    model = await session.get(UserBackup, backup_id)
    if model is None or model.user_id != user_id:
        raise NotFoundError("Backup", backup_id)
    return model


async def get_latest_backup(
    session: AsyncSession, user_id: int, kind: str | None = None
) -> UserBackup | None:
    query = select(UserBackup).where(UserBackup.user_id == user_id)
    if kind is not None:
        query = query.where(UserBackup.kind == kind)
    return await session.scalar(query.order_by(UserBackup.id.desc()).limit(1))


async def rename_backup(
    session: AsyncSession, user_id: int, backup_id: int, name: str | None
) -> BackupSummary:
    model = await get_backup(session, user_id, backup_id)
    model.name = name
    await session.commit()
    await session.refresh(model)
    return _to_summary(model)


async def delete_backup(session: AsyncSession, user_id: int, backup_id: int) -> None:
    model = await get_backup(session, user_id, backup_id)
    await session.delete(model)
    await session.commit()


async def prune_backups(session: AsyncSession, user_id: int, kind: str, keep: int) -> None:
    """Keeps only the newest `keep` backups of one kind for the user."""
    stale_ids = (
        await session.scalars(
            select(UserBackup.id)
            .where(UserBackup.user_id == user_id, UserBackup.kind == kind)
            .order_by(UserBackup.id.desc())
            .offset(keep)
        )
    ).all()
    if stale_ids:
        await session.execute(delete(UserBackup).where(UserBackup.id.in_(stale_ids)))
        await session.commit()

import msgspec
from sqlalchemy import delete, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, ValidationError, handle_database_error
from backlog_manager_backend.models.backlog_entry import BacklogEntry
from backlog_manager_backend.models.category import Category
from backlog_manager_backend.models.category_backlog_entry import CategoryBacklogEntry
from backlog_manager_backend.models.custom_status import CustomStatus
from backlog_manager_backend.models.user_backup import UserBackup
from backlog_manager_backend.schemas.backup import (
    PAYLOAD_VERSION,
    BackupCategory,
    BackupCustomStatus,
    BackupEntry,
    BackupPayload,
    BackupSummary,
)

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
    "main_time",
    "main_plus_extra_time",
    "completion_time",
    "playtime",
    "steam_app_id",
    "review_stars",
    "review",
    "note",
    "completed_at",
]


def _to_summary(model: UserBackup) -> BackupSummary:
    return BackupSummary(
        id=model.id,
        kind=model.kind,
        created_at=model.created_at,
        entry_count=model.entry_count,
        category_count=model.category_count,
    )


async def load_user_content(session: AsyncSession, user_id: int) -> BackupPayload:
    """Reads the user's whole personal backlog content (SpaceID IS NULL -
    shared space rows carry their creator's UserID but belong to two
    people) into a snapshot payload, ordered by id so the same content always serialises the
    same way."""
    entry_models = (
        await session.scalars(
            select(BacklogEntry)
            .where(BacklogEntry.user_id == user_id, BacklogEntry.space_id.is_(None))
            .order_by(BacklogEntry.id)
        )
    ).all()
    refs = {model.id: position for position, model in enumerate(entry_models, start=1)}

    links = (
        await session.execute(
            select(CategoryBacklogEntry.category_id, CategoryBacklogEntry.backlog_entry_id)
            .join(Category, Category.id == CategoryBacklogEntry.category_id)
            .where(Category.user_id == user_id, Category.space_id.is_(None))
        )
    ).all()
    refs_by_category: dict[int, list[int]] = {}
    for category_id, entry_id in links:
        refs_by_category.setdefault(category_id, []).append(refs[entry_id])

    category_models = (
        await session.scalars(
            select(Category)
            .where(Category.user_id == user_id, Category.space_id.is_(None))
            .order_by(Category.id)
        )
    ).all()
    status_models = (
        await session.scalars(
            select(CustomStatus)
            .where(CustomStatus.user_id == user_id, CustomStatus.space_id.is_(None))
            .order_by(CustomStatus.id)
        )
    ).all()

    return BackupPayload(
        version=PAYLOAD_VERSION,
        entries=[
            BackupEntry(
                ref=refs[model.id], **{field: getattr(model, field) for field in _ENTRY_FIELDS}
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


async def replace_user_content(
    session: AsyncSession, user_id: int, payload: BackupPayload
) -> None:
    """Swaps the user's whole personal backlog content (never shared space
    rows) for the payload in one transaction: any failure (a payload the database rejects, e.g.
    two entries sharing a Steam app id) rolls back to the untouched
    previous content. Rows are re-created with fresh ids - category links
    are rebuilt from the payload's refs."""
    try:
        await session.execute(delete(BacklogEntry).where(
                BacklogEntry.user_id == user_id, BacklogEntry.space_id.is_(None)
            )
        )
        await session.execute(delete(Category).where(Category.user_id == user_id, Category.space_id.is_(None))
        )
        await session.execute(delete(CustomStatus).where(
                CustomStatus.user_id == user_id, CustomStatus.space_id.is_(None)
            )
        )

        entry_models = {
            entry.ref: BacklogEntry(
                user_id=user_id,
                **{field: getattr(entry, field) for field in _ENTRY_FIELDS},
            )
            for entry in payload.entries
        }
        session.add_all(entry_models.values())
        await session.flush()

        for category in payload.categories:
            category_model = Category(
                user_id=user_id,
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
                name=status.name,
                created_at=status.created_at,
                updated_at=status.updated_at,
            )
            for status in payload.custom_statuses
        )
        await session.commit()
    except DBAPIError as error:
        await session.rollback()
        handle_database_error(error, "replace_user_content")
    except ValidationError:
        await session.rollback()
        raise


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

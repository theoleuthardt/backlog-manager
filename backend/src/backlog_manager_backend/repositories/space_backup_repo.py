from datetime import UTC, datetime, timedelta

import msgspec
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, NotFoundError
from backlog_manager_backend.models.space import Space, SpaceMember
from backlog_manager_backend.models.space_backup import SpaceBackup, SpaceRestoreRequest
from backlog_manager_backend.models.space_entry_member_data import SpaceEntryMemberData
from backlog_manager_backend.models.user import User
from backlog_manager_backend.repositories import backup_repo
from backlog_manager_backend.schemas.backup import BackupSummary
from backlog_manager_backend.schemas.space_backup import (
    SpaceBackupMemberData,
    SpaceBackupPayload,
    SpaceBackupSummary,
)


def _to_summary(model: SpaceBackup, created_by: str | None) -> SpaceBackupSummary:
    return SpaceBackupSummary(
        id=model.id,
        kind=model.kind,
        name=model.name,
        created_at=model.created_at,
        entry_count=model.entry_count,
        category_count=model.category_count,
        created_by=created_by,
    )


async def load_space_content(session: AsyncSession, space_id: int) -> SpaceBackupPayload:
    """Reads the whole content of the space, the per-member fields of both
    members included."""
    payload, refs = await backup_repo.load_content(session, 0, space_id)
    rows = (
        await session.scalars(
            select(SpaceEntryMemberData)
            .where(SpaceEntryMemberData.backlog_entry_id.in_(refs))
            .order_by(SpaceEntryMemberData.backlog_entry_id, SpaceEntryMemberData.user_id)
        )
    ).all()
    return SpaceBackupPayload(
        version=payload.version,
        entries=payload.entries,
        categories=payload.categories,
        custom_statuses=payload.custom_statuses,
        member_data=[
            SpaceBackupMemberData(
                ref=refs[row.backlog_entry_id],
                user_id=row.user_id,
                playtime=row.playtime,
                review_stars=row.review_stars,
                review=row.review,
                owned=row.owned,
            )
            for row in rows
        ],
    )


async def replace_space_content(
    session: AsyncSession, space_id: int, owner_id: int, payload: SpaceBackupPayload
) -> None:
    """Swaps the whole content of the space for the payload in one
    transaction; `owner_id` becomes the creator of every row."""
    await backup_repo.replace_content(
        session, owner_id, payload, space_id=space_id, member_data=payload.member_data
    )


async def create_backup(
    session: AsyncSession,
    space_id: int,
    created_by: int | None,
    kind: str,
    content_hash: str,
    payload: SpaceBackupPayload,
) -> SpaceBackupSummary:
    model = SpaceBackup(
        space_id=space_id,
        created_by=created_by,
        kind=kind,
        content_hash=content_hash,
        entry_count=len(payload.entries),
        category_count=len(payload.categories),
        payload=msgspec.to_builtins(payload),
    )
    session.add(model)
    await session.commit()
    await session.refresh(model)
    return _to_summary(model, await _username(session, created_by))


async def _username(session: AsyncSession, user_id: int | None) -> str | None:
    if user_id is None:
        return None
    return await session.scalar(select(User.username).where(User.id == user_id))


async def list_backups(session: AsyncSession, space_id: int) -> list[SpaceBackupSummary]:
    result = await session.execute(
        select(SpaceBackup, User.username)
        .outerjoin(User, User.id == SpaceBackup.created_by)
        .where(SpaceBackup.space_id == space_id)
        .order_by(SpaceBackup.id.desc())
    )
    return [_to_summary(model, username) for model, username in result.all()]


async def get_backup(session: AsyncSession, space_id: int, backup_id: int) -> SpaceBackup:
    """Scoped to the space: another space's backup is indistinguishable
    from a missing one."""
    model = await session.get(SpaceBackup, backup_id)
    if model is None or model.space_id != space_id:
        raise NotFoundError("Backup", backup_id)
    return model


async def get_latest_backup(
    session: AsyncSession, space_id: int, kind: str | None = None
) -> SpaceBackup | None:
    query = select(SpaceBackup).where(SpaceBackup.space_id == space_id)
    if kind is not None:
        query = query.where(SpaceBackup.kind == kind)
    return await session.scalar(query.order_by(SpaceBackup.id.desc()).limit(1))


async def rename_backup(
    session: AsyncSession, space_id: int, backup_id: int, name: str | None
) -> BackupSummary:
    model = await get_backup(session, space_id, backup_id)
    model.name = name
    await session.commit()
    await session.refresh(model)
    return _to_summary(model, await _username(session, model.created_by))


async def delete_backup(session: AsyncSession, space_id: int, backup_id: int) -> None:
    model = await get_backup(session, space_id, backup_id)
    await session.delete(model)
    await session.commit()


async def prune_backups(session: AsyncSession, space_id: int, kind: str, keep: int) -> None:
    """Keeps only the newest `keep` backups of one kind of the space."""
    stale_ids = (
        await session.scalars(
            select(SpaceBackup.id)
            .where(SpaceBackup.space_id == space_id, SpaceBackup.kind == kind)
            .order_by(SpaceBackup.id.desc())
            .offset(keep)
        )
    ).all()
    if stale_ids:
        await session.execute(delete(SpaceBackup).where(SpaceBackup.id.in_(stale_ids)))
        await session.commit()


async def get_space_ids_with_members(session: AsyncSession) -> list[int]:
    """The spaces that have at least one active member."""
    return list(
        (
            await session.scalars(
                select(Space.id)
                .where(
                    Space.id.in_(select(SpaceMember.space_id).where(SpaceMember.status == "active"))
                )
                .order_by(Space.id)
            )
        ).all()
    )


async def delete_expired_requests(session: AsyncSession, ttl: timedelta) -> None:
    due_before = datetime.now(UTC).replace(tzinfo=None) - ttl
    await session.execute(
        delete(SpaceRestoreRequest).where(SpaceRestoreRequest.created_at <= due_before)
    )
    await session.commit()


async def get_request(
    session: AsyncSession, space_id: int
) -> tuple[SpaceRestoreRequest, SpaceBackup, str] | None:
    """The open restore request of the space with its backup and the
    username of the member who asked."""
    row = (
        await session.execute(
            select(SpaceRestoreRequest, SpaceBackup, User.username)
            .join(SpaceBackup, SpaceBackup.id == SpaceRestoreRequest.backup_id)
            .join(User, User.id == SpaceRestoreRequest.requested_by)
            .where(SpaceRestoreRequest.space_id == space_id)
        )
    ).first()
    return None if row is None else (row[0], row[1], row[2])


async def create_request(
    session: AsyncSession, space_id: int, backup_id: int, requested_by: int
) -> None:
    session.add(
        SpaceRestoreRequest(space_id=space_id, backup_id=backup_id, requested_by=requested_by)
    )
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        raise ConflictError("A restore is already waiting for approval") from error


async def claim_request(session: AsyncSession, space_id: int, request_id: int) -> bool:
    """Deletes the request and says whether it was there, so two members
    acting at once cannot both run it."""
    result = await session.execute(
        delete(SpaceRestoreRequest)
        .where(SpaceRestoreRequest.id == request_id, SpaceRestoreRequest.space_id == space_id)
        .returning(SpaceRestoreRequest.id)
    )
    claimed = result.first() is not None
    await session.commit()
    return claimed


async def delete_requests(session: AsyncSession, space_id: int) -> None:
    await session.execute(
        delete(SpaceRestoreRequest).where(SpaceRestoreRequest.space_id == space_id)
    )
    await session.commit()

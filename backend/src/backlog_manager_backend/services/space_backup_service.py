"""Snapshots, restores and the export of a shared space.

Snapshots are taken automatically (`create_due_auto_backups`, called by the
scheduler of backup_service), on request (kind "manual") and as safety nets
right before the space is emptied or restored ("pre-delete",
"pre-restore"). Like the personal backups, every kind except "manual" is
skipped for an empty space or one identical to the latest snapshot of the
same kind, and retention is counted per kind.

Either member can take a snapshot. A restore needs both: one member asks
for it (`request_restore`), the other has to approve it
(`approve_restore`) within RESTORE_REQUEST_TTL, and either of them can
withdraw it (`withdraw_restore_request`). A space with a single active
member restores at once, nobody else could approve. A member only ever
receives their own per-member fields (playtime, rating, review, ownership)
in a download or the export; the stored snapshot has both members' so that
a restore brings both back."""

import hashlib
from datetime import UTC, datetime, timedelta

import msgspec
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError
from backlog_manager_backend.repositories import space_backup_repo, space_repo
from backlog_manager_backend.schemas.backup import (
    MAX_BACKUP_NAME_LENGTH,
    PAYLOAD_VERSION,
    BackupSummary,
    RestoreResult,
)
from backlog_manager_backend.schemas.space_backup import (
    RestoreRequestResponse,
    SpaceBackupList,
    SpaceBackupPayload,
    SpaceBackupSummary,
    SpaceRestoreResponse,
)
from backlog_manager_backend.schemas.user import User

logger = structlog.get_logger()

AUTO = "auto"
MANUAL = "manual"
PRE_RESTORE = "pre-restore"
PRE_DELETE = "pre-delete"

RETENTION = {AUTO: 14, MANUAL: 20, PRE_RESTORE: 5, PRE_DELETE: 5}

AUTO_BACKUP_INTERVAL = timedelta(hours=22)
RESTORE_REQUEST_TTL = timedelta(hours=24)

_UNREADABLE_BACKUP = "This backup is corrupt or was made by an incompatible version"


def _content_hash(payload: SpaceBackupPayload) -> str:
    return hashlib.sha256(msgspec.json.encode(payload, order="sorted")).hexdigest()


def _decode_payload(raw: dict) -> SpaceBackupPayload:
    if raw.get("version") != PAYLOAD_VERSION:
        raise ValidationError(_UNREADABLE_BACKUP)
    try:
        return msgspec.json.decode(msgspec.json.encode(raw), type=SpaceBackupPayload)
    except msgspec.DecodeError as error:
        raise ValidationError(_UNREADABLE_BACKUP) from error


def _for_member(payload: SpaceBackupPayload, user_id: int) -> SpaceBackupPayload:
    return msgspec.structs.replace(
        payload, member_data=[row for row in payload.member_data if row.user_id == user_id]
    )


async def _active_space_id(session: AsyncSession, user: User) -> int:
    """A user without an active membership gets the same not-found as a
    space that does not exist."""
    membership = await space_repo.get_membership(session, user.id)
    if membership is None or membership.status != "active":
        raise NotFoundError("Space", user.id)
    return membership.space_id


async def _store_backup(
    session: AsyncSession,
    space_id: int,
    created_by: int | None,
    kind: str,
    payload: SpaceBackupPayload,
) -> SpaceBackupSummary:
    backup = await space_backup_repo.create_backup(
        session, space_id, created_by, kind, _content_hash(payload), payload
    )
    await space_backup_repo.prune_backups(session, space_id, kind, RETENTION[kind])
    return backup


async def create_manual_backup(session: AsyncSession, user: User) -> SpaceBackupSummary:
    """Always stores a snapshot, even of an empty or unchanged space."""
    space_id = await _active_space_id(session, user)
    payload = await space_backup_repo.load_space_content(session, space_id)
    return await _store_backup(session, space_id, user.id, MANUAL, payload)


async def create_backup(
    session: AsyncSession, space_id: int, kind: str, created_by: int | None = None
) -> SpaceBackupSummary | None:
    """Automatic and safety snapshots: None means it was skipped (see the
    module docstring)."""
    payload = await space_backup_repo.load_space_content(session, space_id)
    if not payload.entries and not payload.categories:
        return None
    latest = await space_backup_repo.get_latest_backup(session, space_id, kind)
    if latest is not None and latest.content_hash == _content_hash(payload):
        return None
    return await _store_backup(session, space_id, created_by, kind, payload)


async def _request_response(
    session: AsyncSession, space_id: int, viewer_id: int
) -> RestoreRequestResponse | None:
    await space_backup_repo.delete_expired_requests(session, RESTORE_REQUEST_TTL)
    found = await space_backup_repo.get_request(session, space_id)
    if found is None:
        return None
    request, backup, requester = found
    return RestoreRequestResponse(
        id=request.id,
        backup_id=backup.id,
        backup_name=backup.name,
        backup_created_at=backup.created_at,
        requested_by=requester,
        requested_by_me=request.requested_by == viewer_id,
        created_at=request.created_at,
        expires_at=request.created_at + RESTORE_REQUEST_TTL,
    )


async def list_backups(session: AsyncSession, user: User) -> SpaceBackupList:
    space_id = await _active_space_id(session, user)
    return SpaceBackupList(
        backups=await space_backup_repo.list_backups(session, space_id),
        restore_request=await _request_response(session, space_id, user.id),
    )


async def export_backup(session: AsyncSession, user: User, backup_id: int) -> SpaceBackupPayload:
    space_id = await _active_space_id(session, user)
    backup = await space_backup_repo.get_backup(session, space_id, backup_id)
    return _for_member(_decode_payload(backup.payload), user.id)


async def export_space(session: AsyncSession, user: User) -> SpaceBackupPayload:
    """The current content of the space, the caller's own per-member
    fields included."""
    space_id = await _active_space_id(session, user)
    return _for_member(await space_backup_repo.load_space_content(session, space_id), user.id)


async def rename_backup(
    session: AsyncSession, user: User, backup_id: int, name: str | None
) -> BackupSummary:
    """Surrounding whitespace is trimmed and a blank name clears the label."""
    space_id = await _active_space_id(session, user)
    cleaned = name.strip() if name else None
    if cleaned and len(cleaned) > MAX_BACKUP_NAME_LENGTH:
        raise ValidationError(f"Name must be at most {MAX_BACKUP_NAME_LENGTH} characters long")
    return await space_backup_repo.rename_backup(session, space_id, backup_id, cleaned or None)


async def delete_backup(session: AsyncSession, user: User, backup_id: int) -> None:
    space_id = await _active_space_id(session, user)
    await space_backup_repo.delete_backup(session, space_id, backup_id)


async def _run_restore(
    session: AsyncSession, space_id: int, user: User, payload: SpaceBackupPayload
) -> RestoreResult:
    """Takes a "pre-restore" snapshot of the current state first (so the
    restore can be undone by restoring that one), then swaps the content in
    one transaction. `user` becomes the creator of the restored rows."""
    safety_backup = await create_backup(session, space_id, PRE_RESTORE, user.id)
    await space_backup_repo.replace_space_content(session, space_id, user.id, payload)
    logger.info("space_backup_restored", space_id=space_id, user_id=user.id)
    return RestoreResult(
        entry_count=len(payload.entries),
        category_count=len(payload.categories),
        safety_backup_id=safety_backup.id if safety_backup else None,
    )


async def request_restore(
    session: AsyncSession, user: User, backup_id: int
) -> SpaceRestoreResponse:
    """Asks for the restore of a backup. The backup is decoded first, so a
    corrupt one is refused before anyone is asked. Restores at once when
    the user is the only active member."""
    space_id = await _active_space_id(session, user)
    backup = await space_backup_repo.get_backup(session, space_id, backup_id)
    payload = _decode_payload(backup.payload)

    members = await space_repo.get_members(session, space_id)
    if sum(1 for member in members if member.status == "active") < 2:
        result = await _run_restore(session, space_id, user, payload)
        return SpaceRestoreResponse(restored=True, result=result)

    await space_backup_repo.delete_expired_requests(session, RESTORE_REQUEST_TTL)
    await space_backup_repo.create_request(session, space_id, backup_id, user.id)
    return SpaceRestoreResponse(
        restored=False, request=await _request_response(session, space_id, user.id)
    )


async def approve_restore(session: AsyncSession, user: User) -> RestoreResult:
    """The member who did not ask for the restore lets it run."""
    space_id = await _active_space_id(session, user)
    pending = await _request_response(session, space_id, user.id)
    if pending is None:
        raise NotFoundError("RestoreRequest", space_id)
    if pending.requested_by_me:
        raise ConflictError("The other member has to approve this restore")
    backup = await space_backup_repo.get_backup(session, space_id, pending.backup_id)
    payload = _decode_payload(backup.payload)
    if not await space_backup_repo.claim_request(session, space_id, pending.id):
        raise NotFoundError("RestoreRequest", space_id)
    return await _run_restore(session, space_id, user, payload)


async def withdraw_restore_request(session: AsyncSession, user: User) -> None:
    """Either member can end the open request: the one who asked takes it
    back, the other declines it."""
    space_id = await _active_space_id(session, user)
    await space_backup_repo.delete_requests(session, space_id)


async def create_due_auto_backups(session: AsyncSession) -> None:
    """One scheduler tick: snapshots every space whose last automatic
    backup is older than AUTO_BACKUP_INTERVAL (or that has none). A failure
    for one space is logged and rolled back so it cannot stop the others."""
    due_before = datetime.now(UTC).replace(tzinfo=None) - AUTO_BACKUP_INTERVAL
    for space_id in await space_backup_repo.get_space_ids_with_members(session):
        try:
            latest_auto = await space_backup_repo.get_latest_backup(session, space_id, AUTO)
            if latest_auto is not None and latest_auto.created_at > due_before:
                continue
            await create_backup(session, space_id, AUTO)
        except Exception:
            await session.rollback()
            logger.exception("space_auto_backup_failed", space_id=space_id)

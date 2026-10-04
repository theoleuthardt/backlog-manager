"""Snapshots and restores of a user's personal backlog content.

Backups are taken automatically (`create_due_auto_backups`, driven by the
scheduler in app.py), on request (kind "manual") and as safety nets right
before something destructive (kinds "pre-restore", "pre-delete",
"pre-import"). Every kind except "manual" is skipped when the backlog is
empty (nothing to protect, and an empty snapshot must never push real ones
out through retention) or identical to the user's latest backup of the same
kind (so a safety snapshot is still stored when a manual backup happens to
hold the same content - it is what the restore's undo points at). Retention
is counted per kind in RETENTION, so a burst of safety snapshots can't
evict the daily ones."""

import asyncio
import hashlib
from datetime import UTC, datetime, timedelta

import msgspec
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.db import async_session
from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.repositories import backup_repo, user_repo
from backlog_manager_backend.schemas.backup import (
    PAYLOAD_VERSION,
    BackupPayload,
    BackupSummary,
    RestoreResult,
)

logger = structlog.get_logger()

AUTO = "auto"
MANUAL = "manual"
PRE_RESTORE = "pre-restore"
PRE_DELETE = "pre-delete"
PRE_IMPORT = "pre-import"

RETENTION = {AUTO: 14, MANUAL: 20, PRE_RESTORE: 5, PRE_DELETE: 5, PRE_IMPORT: 5}

AUTO_BACKUP_INTERVAL = timedelta(hours=22)

_UNREADABLE_BACKUP = "This backup is corrupt or was made by an incompatible version"


def _content_hash(payload: BackupPayload) -> str:
    return hashlib.sha256(msgspec.json.encode(payload, order="sorted")).hexdigest()


def _decode_payload(raw: dict) -> BackupPayload:
    if raw.get("version") != PAYLOAD_VERSION:
        raise ValidationError(_UNREADABLE_BACKUP)
    try:
        return msgspec.json.decode(msgspec.json.encode(raw), type=BackupPayload)
    except msgspec.DecodeError as error:
        raise ValidationError(_UNREADABLE_BACKUP) from error


async def _store_backup(
    session: AsyncSession, user_id: int, kind: str, payload: BackupPayload
) -> BackupSummary:
    backup = await backup_repo.create_backup(
        session, user_id, kind, _content_hash(payload), payload
    )
    await backup_repo.prune_backups(session, user_id, kind, RETENTION[kind])
    return backup


async def create_manual_backup(session: AsyncSession, user_id: int) -> BackupSummary:
    """Always stores a snapshot, even of an empty or unchanged backlog."""
    payload = await backup_repo.load_user_content(session, user_id)
    return await _store_backup(session, user_id, MANUAL, payload)


async def create_backup(session: AsyncSession, user_id: int, kind: str) -> BackupSummary | None:
    """Automatic and safety snapshots: None means it was skipped (see
    module docstring)."""
    payload = await backup_repo.load_user_content(session, user_id)
    if not payload.entries and not payload.categories:
        return None

    latest = await backup_repo.get_latest_backup(session, user_id, kind)
    if latest is not None and latest.content_hash == _content_hash(payload):
        return None

    return await _store_backup(session, user_id, kind, payload)


async def list_backups(session: AsyncSession, user_id: int) -> list[BackupSummary]:
    return await backup_repo.list_backups(session, user_id)


async def export_backup(session: AsyncSession, user_id: int, backup_id: int) -> BackupPayload:
    backup = await backup_repo.get_backup(session, user_id, backup_id)
    return _decode_payload(backup.payload)


async def delete_backup(session: AsyncSession, user_id: int, backup_id: int) -> None:
    await backup_repo.delete_backup(session, user_id, backup_id)


async def restore_backup(session: AsyncSession, user_id: int, backup_id: int) -> RestoreResult:
    """Replaces the user's current content with the backup's. The backup is
    fully decoded and validated before anything is touched, a "pre-restore"
    snapshot of the current state is taken first (so the restore itself can
    be undone by restoring that one), and the swap is a single transaction.
    `safety_backup_id` is None when the current state was empty or already
    identical to the latest pre-restore backup."""
    backup = await backup_repo.get_backup(session, user_id, backup_id)
    payload = _decode_payload(backup.payload)

    safety_backup = await create_backup(session, user_id, PRE_RESTORE)
    await backup_repo.replace_user_content(session, user_id, payload)

    logger.info("backup_restored", user_id=user_id, backup_id=backup_id)
    return RestoreResult(
        entry_count=len(payload.entries),
        category_count=len(payload.categories),
        safety_backup_id=safety_backup.id if safety_backup else None,
    )


async def create_due_auto_backups(session: AsyncSession) -> None:
    """One scheduler tick: snapshots every user whose last automatic
    backup is older than AUTO_BACKUP_INTERVAL (or who has none). A failure
    for one user is logged and rolled back so it cannot stop the others
    from being backed up."""
    due_before = datetime.now(UTC).replace(tzinfo=None) - AUTO_BACKUP_INTERVAL
    for user in await user_repo.get_all_users(session):
        try:
            latest_auto = await backup_repo.get_latest_backup(session, user.id, AUTO)
            if latest_auto is not None and latest_auto.created_at > due_before:
                continue
            await create_backup(session, user.id, AUTO)
        except Exception:
            await session.rollback()
            logger.exception("auto_backup_failed", user_id=user.id)


async def run_scheduler(interval_seconds: float) -> None:
    """Runs create_due_auto_backups every `interval_seconds` until
    cancelled. A failed tick is logged and retried next time rather than
    ending the loop - a transient database error must not silently stop
    backups for the rest of the process's life."""
    while True:
        try:
            async with async_session() as session:
                await create_due_auto_backups(session)
        except Exception:
            logger.exception("auto_backup_tick_failed")
        await asyncio.sleep(interval_seconds)

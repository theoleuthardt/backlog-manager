"""Snapshot format and responses of the shared space backups.

The payload is the personal backup payload (`schemas/backup.py`) plus the
per-member fields of every entry (`member_data`, one row per member and
entry ref). A member only ever receives their own rows: see
`services/space_backup_service.py`."""

from datetime import datetime
from decimal import Decimal

import msgspec

from backlog_manager_backend.schemas.backup import BackupPayload, BackupSummary, RestoreResult


class SpaceBackupMemberData(msgspec.Struct):
    ref: int
    user_id: int
    playtime: Decimal | None = None
    review_stars: int | None = None
    review: str | None = None
    owned: bool | None = None


class SpaceBackupPayload(BackupPayload):
    member_data: list[SpaceBackupMemberData] = msgspec.field(default_factory=list)


class SpaceBackupSummary(BackupSummary):
    """`created_by` is the username of the member who took the snapshot,
    None for automatic ones and for a member who has left."""

    created_by: str | None = None


class RestoreRequestResponse(msgspec.Struct):
    """A restore one member asked for and the other still has to approve;
    it lapses at `expires_at`."""

    id: int
    backup_id: int
    backup_created_at: datetime
    requested_by: str
    requested_by_me: bool
    created_at: datetime
    expires_at: datetime
    backup_name: str | None = None


class SpaceBackupList(msgspec.Struct):
    backups: list[SpaceBackupSummary]
    restore_request: RestoreRequestResponse | None = None


class SpaceRestoreResponse(msgspec.Struct):
    """Either the restore ran (`restored`, with its `result`) or it waits
    for the other member (`request`)."""

    restored: bool
    request: RestoreRequestResponse | None = None
    result: RestoreResult | None = None

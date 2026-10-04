"""Versioned snapshot format of a user's personal backlog content.

`ref` values are 1-based positions inside the payload, not database ids:
categories point at their entries through them, and because they carry no
database identity two snapshots of identical content hash identically (see
services/backup_service.py's duplicate skipping), even after a restore
re-created every row with fresh ids."""

from datetime import date, datetime
from decimal import Decimal
from typing import Annotated

import msgspec

PAYLOAD_VERSION = 1


class BackupEntry(msgspec.Struct):
    ref: int
    title: str
    genre: str
    platform: str
    status: str
    owned: bool
    interest: Annotated[int, msgspec.Meta(ge=1, le=10)]
    created_at: datetime
    updated_at: datetime
    release_date: date | None = None
    image_link: str | None = None
    description: str | None = None
    trailer_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None
    playtime: Decimal | None = None
    steam_app_id: int | None = None
    review_stars: int | None = None
    review: str | None = None
    note: str | None = None
    completed_at: datetime | None = None


class BackupCategory(msgspec.Struct):
    name: str
    color: str
    created_at: datetime
    updated_at: datetime
    description: str | None = None
    entry_refs: list[int] = msgspec.field(default_factory=list)


class BackupCustomStatus(msgspec.Struct):
    name: str
    created_at: datetime
    updated_at: datetime


class BackupPayload(msgspec.Struct):
    version: int
    entries: list[BackupEntry]
    categories: list[BackupCategory]
    custom_statuses: list[BackupCustomStatus]


MAX_BACKUP_NAME_LENGTH = 60


class BackupSummary(msgspec.Struct):
    id: int
    kind: str
    created_at: datetime
    entry_count: int
    category_count: int
    name: str | None = None


class RenameBackupRequest(msgspec.Struct):
    """A blank or null name clears the label."""

    name: Annotated[str, msgspec.Meta(max_length=MAX_BACKUP_NAME_LENGTH)] | None = None


class RestoreResult(msgspec.Struct):
    entry_count: int
    category_count: int
    safety_backup_id: int | None = None

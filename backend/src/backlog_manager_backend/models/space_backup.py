from datetime import datetime
from typing import Any, ClassVar

from sqlalchemy import BigInteger, ForeignKey, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import Base

_UTC_CLOCK = text("timezone('utc', clock_timestamp())")


class SpaceBackup(Base):
    """A full snapshot of one shared space (entries, categories, statuses,
    mods and the per-member fields) as the versioned JSON payload of
    schemas/space_backup.py. `CreatedBy` is NULL for automatic snapshots
    and once the member who took it is gone. Like UserBackup, `CreatedAt`
    is a UTC clock timestamp with sub-minute precision."""

    __tablename__ = "SpaceBackups"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    id: Mapped[int] = mapped_column("BackupID", BigInteger, primary_key=True)
    space_id: Mapped[int] = mapped_column(
        "SpaceID",
        BigInteger,
        ForeignKey("blm-system.Spaces.SpaceID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    created_by: Mapped[int | None] = mapped_column(
        "CreatedBy",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="SET NULL", onupdate="CASCADE"),
    )
    kind: Mapped[str] = mapped_column("Kind")
    name: Mapped[str | None] = mapped_column("Name")
    content_hash: Mapped[str] = mapped_column("ContentHash")
    entry_count: Mapped[int] = mapped_column("EntryCount")
    category_count: Mapped[int] = mapped_column("CategoryCount")
    payload: Mapped[dict[str, Any]] = mapped_column("Payload", JSONB)
    created_at: Mapped[datetime] = mapped_column("CreatedAt", server_default=_UTC_CLOCK)


class SpaceRestoreRequest(Base):
    """The open request to restore a backup of a space: SpaceID is unique,
    so a space has at most one. The other member approves it (the row is
    deleted and the restore runs) or either member deletes it."""

    __tablename__ = "SpaceRestoreRequests"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    id: Mapped[int] = mapped_column("RequestID", BigInteger, primary_key=True)
    space_id: Mapped[int] = mapped_column(
        "SpaceID",
        BigInteger,
        ForeignKey("blm-system.Spaces.SpaceID", ondelete="CASCADE", onupdate="CASCADE"),
        unique=True,
    )
    backup_id: Mapped[int] = mapped_column(
        "BackupID",
        BigInteger,
        ForeignKey("blm-system.SpaceBackups.BackupID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    requested_by: Mapped[int] = mapped_column(
        "RequestedBy",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    created_at: Mapped[datetime] = mapped_column("CreatedAt", server_default=_UTC_CLOCK)

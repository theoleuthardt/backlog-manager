from datetime import datetime
from typing import Any, ClassVar

from sqlalchemy import BigInteger, ForeignKey, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import Base


class UserBackup(Base):
    """A full snapshot of one user's personal backlog content (entries,
    categories with their links, custom statuses) as the versioned JSON
    payload defined in schemas/backup.py. `CreatedAt` is a UTC clock
    timestamp with sub-minute precision, unlike the minute-truncated
    timestamps elsewhere: several backups can be taken within a minute and
    the scheduler compares it against a 22-hour interval."""

    __tablename__ = "UserBackups"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    id: Mapped[int] = mapped_column("BackupID", BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    kind: Mapped[str] = mapped_column("Kind")
    content_hash: Mapped[str] = mapped_column("ContentHash")
    entry_count: Mapped[int] = mapped_column("EntryCount")
    category_count: Mapped[int] = mapped_column("CategoryCount")
    payload: Mapped[dict[str, Any]] = mapped_column("Payload", JSONB)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=text("timezone('utc', clock_timestamp())")
    )

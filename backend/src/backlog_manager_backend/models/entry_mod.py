from datetime import datetime
from typing import ClassVar

from sqlalchemy import BigInteger, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class EntryMod(Base):
    """A mod of one entry, with its name and an optional link. It belongs to
    the entry, so it is shared by both members of a shared space and removed
    with the entry."""

    __tablename__ = "BacklogEntryMods"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    id: Mapped[int] = mapped_column("ModID", BigInteger, primary_key=True)
    backlog_entry_id: Mapped[int] = mapped_column(
        "BacklogEntryID",
        BigInteger,
        ForeignKey(
            "blm-system.BacklogEntries.BacklogEntryID", ondelete="CASCADE", onupdate="CASCADE"
        ),
    )
    name: Mapped[str] = mapped_column("Name", String(120))
    url: Mapped[str | None] = mapped_column("Url", Text)
    created_at: Mapped[datetime] = mapped_column("CreatedAt", server_default=TIMESTAMP_DEFAULT)
    updated_at: Mapped[datetime] = mapped_column("UpdatedAt", server_default=TIMESTAMP_DEFAULT)

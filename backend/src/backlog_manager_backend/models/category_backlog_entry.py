from datetime import datetime
from typing import ClassVar

from sqlalchemy import BigInteger, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class CategoryBacklogEntry(Base):
    __tablename__ = "CategoryBacklogEntries"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    category_id: Mapped[int] = mapped_column(
        "CategoryID",
        BigInteger,
        ForeignKey(
            "blm-system.Categories.CategoryID", ondelete="CASCADE", onupdate="CASCADE"
        ),
        primary_key=True,
    )
    backlog_entry_id: Mapped[int] = mapped_column(
        "BacklogEntryID",
        BigInteger,
        ForeignKey(
            "blm-system.BacklogEntries.BacklogEntryID",
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        primary_key=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )

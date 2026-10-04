from decimal import Decimal
from typing import ClassVar

from sqlalchemy import BigInteger, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import Base


class SpaceEntryMemberData(Base):
    """The fields of a shared-space entry that belong to one member
    rather than the whole space: their own playtime, rating and review."""

    __tablename__ = "SpaceEntryMemberData"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

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
    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )
    playtime: Mapped[Decimal | None] = mapped_column("Playtime")
    review_stars: Mapped[int | None] = mapped_column("ReviewStars")
    review: Mapped[str | None] = mapped_column("Review")

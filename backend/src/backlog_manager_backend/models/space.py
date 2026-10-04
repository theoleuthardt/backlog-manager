from datetime import datetime
from typing import ClassVar

from sqlalchemy import BigInteger, CheckConstraint, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class Space(Base):
    """A shared backlog of at most two users, see SpaceMember."""

    __tablename__ = "Spaces"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    id: Mapped[int] = mapped_column("SpaceID", BigInteger, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )


class SpaceMember(Base):
    """UserID is globally unique: a user belongs to (or is invited to)
    at most one space. Status is "invited" until the invitee accepts,
    then "active"."""

    __tablename__ = "SpaceMembers"
    __table_args__ = (
        CheckConstraint(
            "\"Status\" IN ('invited', 'active')", name="SpaceMembers_Status_check"
        ),
        {"schema": "blm-system"},
    )

    space_id: Mapped[int] = mapped_column(
        "SpaceID",
        BigInteger,
        ForeignKey("blm-system.Spaces.SpaceID", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
        unique=True,
    )
    status: Mapped[str] = mapped_column("Status")
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )

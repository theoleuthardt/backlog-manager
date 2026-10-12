from typing import ClassVar

from sqlalchemy import BigInteger, ForeignKey, LargeBinary
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import Base


class UserAvatar(Base):
    """The profile picture of one user. Kept apart from "Users" so that
    loading a user never loads the bytes; `Users.AvatarUpdatedAt` says
    whether a picture exists and doubles as its cache version."""

    __tablename__ = "UserAvatars"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )
    content_type: Mapped[str] = mapped_column("ContentType")
    data: Mapped[bytes] = mapped_column("Data", LargeBinary)

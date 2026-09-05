from datetime import datetime
from typing import ClassVar

from sqlalchemy import BigInteger, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class Category(Base):
    __tablename__ = "Categories"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    id: Mapped[int] = mapped_column("CategoryID", BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    name: Mapped[str] = mapped_column("CategoryName")
    color: Mapped[str] = mapped_column("Color")
    description: Mapped[str | None] = mapped_column("Description")
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )

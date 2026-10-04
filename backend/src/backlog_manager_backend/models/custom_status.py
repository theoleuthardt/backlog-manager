from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Index, String, text
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class CustomStatus(Base):
    __tablename__ = "CustomStatuses"
    __table_args__ = (
        Index(
            "CustomStatuses_UserID_Name_key",
            "UserID",
            "Name",
            unique=True,
            postgresql_where=text('"SpaceID" IS NULL'),
        ),
        Index(
            "CustomStatuses_SpaceID_Name_key",
            "SpaceID",
            "Name",
            unique=True,
            postgresql_where=text('"SpaceID" IS NOT NULL'),
        ),
        {"schema": "blm-system"},
    )

    id: Mapped[int] = mapped_column("StatusID", BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    space_id: Mapped[int | None] = mapped_column(
        "SpaceID",
        BigInteger,
        ForeignKey("blm-system.Spaces.SpaceID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    name: Mapped[str] = mapped_column("Name", String(20))
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )
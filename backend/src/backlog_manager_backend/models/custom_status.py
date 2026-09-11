from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class CustomStatus(Base):
    __tablename__ = "CustomStatuses"
    __table_args__ = (
        UniqueConstraint("UserID", "Name", name="CustomStatuses_UserID_Name_key"),
        {"schema": "blm-system"},
    )

    id: Mapped[int] = mapped_column("StatusID", BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    name: Mapped[str] = mapped_column("Name")
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )
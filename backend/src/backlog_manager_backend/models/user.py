from datetime import datetime
from typing import ClassVar

from sqlalchemy import BigInteger, text
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class User(Base):
    __tablename__ = "Users"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    id: Mapped[int] = mapped_column("UserID", BigInteger, primary_key=True)
    username: Mapped[str] = mapped_column("Username", unique=True)
    email: Mapped[str] = mapped_column("Email", unique=True)
    password_hash: Mapped[str] = mapped_column("PasswordHash")
    steam_id: Mapped[str | None] = mapped_column("SteamId")
    is_admin: Mapped[bool] = mapped_column("IsAdmin", server_default=text("false"))
    totp_secret_encrypted: Mapped[str | None] = mapped_column("TotpSecretEncrypted")
    totp_enabled: Mapped[bool] = mapped_column("TotpEnabled", server_default=text("false"))
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )

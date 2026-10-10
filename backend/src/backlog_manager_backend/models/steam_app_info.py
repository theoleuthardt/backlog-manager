from datetime import datetime
from typing import ClassVar

from sqlalchemy import BigInteger
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import Base


class SteamAppInfo(Base):
    """The store name and header image of one Steam app, resolved once and
    shared across all users: the store limits how many lookups it answers,
    and a wishlist import or the hourly wishlist sync would otherwise ask
    again for games it has already named."""

    __tablename__ = "SteamAppInfo"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    steam_app_id: Mapped[int] = mapped_column("SteamAppId", BigInteger, primary_key=True)
    name: Mapped[str] = mapped_column("Name")
    header_image: Mapped[str | None] = mapped_column("HeaderImage")
    resolved_at: Mapped[datetime] = mapped_column("ResolvedAt")

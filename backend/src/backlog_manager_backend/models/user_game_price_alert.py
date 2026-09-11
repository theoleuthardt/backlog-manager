from datetime import datetime
from decimal import Decimal
from typing import ClassVar

from sqlalchemy import BigInteger, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class UserGamePriceAlert(Base):
    """Per-user alert-dedup state: the price a Discord alert was last
    sent to this user for this Steam App ID, so
    price_service.check_prices_and_alert only re-alerts a user when it
    changes - unlike GamePrices, which is shared cache data, this is
    scoped per user since two users tracking the same game may have
    different Discord webhooks and must each be notified independently."""

    __tablename__ = "UserGamePriceAlerts"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )
    steam_app_id: Mapped[int] = mapped_column("SteamAppId", BigInteger, primary_key=True)
    last_alerted_price: Mapped[Decimal] = mapped_column("LastAlertedPrice")
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )

from datetime import datetime
from decimal import Decimal
from typing import ClassVar

from sqlalchemy import BigInteger, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import Base


class GamePrice(Base):
    """One row per Steam App ID tracked by any BacklogEntry - shared
    across all users rather than per-user, since the GG.deals prices are
    the same regardless of who is tracking the game. The four prices are
    the lowest current and historical ones in the official stores
    ("retail") and in keyshops, all in Currency; a price GG.deals does not
    have is NULL, and a game it does not know has all of them NULL.
    Alert-dedup state lives separately, per user, in UserGamePriceAlert -
    two users tracking the same game may have different Discord webhooks
    and must each be notified independently."""

    __tablename__ = "GamePrices"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    steam_app_id: Mapped[int] = mapped_column("SteamAppId", BigInteger, primary_key=True)
    currency: Mapped[str | None] = mapped_column("Currency", String(3))
    current_retail: Mapped[Decimal | None] = mapped_column("CurrentRetail")
    current_keyshops: Mapped[Decimal | None] = mapped_column("CurrentKeyshops")
    historical_retail: Mapped[Decimal | None] = mapped_column("HistoricalRetail")
    historical_keyshops: Mapped[Decimal | None] = mapped_column("HistoricalKeyshops")
    url: Mapped[str | None] = mapped_column("Url", Text)
    checked_at: Mapped[datetime] = mapped_column("CheckedAt")

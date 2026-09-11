from datetime import date, datetime
from decimal import Decimal
from typing import Any, ClassVar

from sqlalchemy import JSON, BigInteger, text
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import Base


class GamePrice(Base):
    """One row per Steam App ID tracked by any BacklogEntry - shared
    across all users rather than per-user, since the underlying
    CheapShark price data is the same regardless of who is tracking it.
    Alert-dedup state lives separately, per user, in
    UserGamePriceAlert - two users tracking the same game may have
    different Discord webhooks and must each be notified independently."""

    __tablename__ = "GamePrices"
    __table_args__: ClassVar[dict[str, str]] = {"schema": "blm-system"}

    steam_app_id: Mapped[int] = mapped_column("SteamAppId", BigInteger, primary_key=True)
    cheapshark_game_id: Mapped[int | None] = mapped_column("CheapsharkGameId", BigInteger)
    deals: Mapped[list[dict[str, Any]] | None] = mapped_column("Deals", JSON)
    cheapest_price_ever: Mapped[Decimal | None] = mapped_column("CheapestPriceEver")
    cheapest_price_ever_date: Mapped[date | None] = mapped_column("CheapestPriceEverDate")
    on_sale: Mapped[bool] = mapped_column("OnSale", server_default=text("false"))
    checked_at: Mapped[datetime] = mapped_column("CheckedAt")

from datetime import datetime
from decimal import Decimal

import msgspec


class GamePrice(msgspec.Struct):
    """The GG.deals prices of a game: the lowest current and the lowest
    ever price in the official stores (retail) and in keyshops, in
    `currency`. `url` is the GG.deals page of the game, to be linked as it
    is. A price GG.deals does not have is null."""

    steam_app_id: int
    checked_at: datetime
    currency: str | None = None
    current_retail: Decimal | None = None
    current_keyshops: Decimal | None = None
    historical_retail: Decimal | None = None
    historical_keyshops: Decimal | None = None
    url: str | None = None


class UpsertGamePriceParams(msgspec.Struct):
    steam_app_id: int
    checked_at: datetime
    currency: str | None = None
    current_retail: Decimal | None = None
    current_keyshops: Decimal | None = None
    historical_retail: Decimal | None = None
    historical_keyshops: Decimal | None = None
    url: str | None = None

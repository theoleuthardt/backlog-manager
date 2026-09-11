from datetime import date, datetime
from decimal import Decimal

import msgspec


class GamePriceDeal(msgspec.Struct):
    store: str
    icon: str
    price: float
    retail_price: float
    url: str


class GamePrice(msgspec.Struct):
    steam_app_id: int
    deals: list[GamePriceDeal]
    on_sale: bool
    checked_at: datetime
    cheapshark_game_id: int | None = None
    cheapest_price_ever: Decimal | None = None
    cheapest_price_ever_date: date | None = None


class UpsertGamePriceParams(msgspec.Struct):
    steam_app_id: int
    deals: list[GamePriceDeal]
    on_sale: bool
    checked_at: datetime
    cheapshark_game_id: int | None = None
    cheapest_price_ever: Decimal | None = None
    cheapest_price_ever_date: date | None = None

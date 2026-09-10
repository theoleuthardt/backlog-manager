from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.models.backlog_entry import BacklogEntry as BacklogEntryModel
from backlog_manager_backend.models.game_price import GamePrice as GamePriceModel
from backlog_manager_backend.schemas.game_price import GamePrice, UpsertGamePriceParams


def _to_schema(model: GamePriceModel) -> GamePrice:
    return GamePrice(
        steam_app_id=model.steam_app_id,
        deals=model.deals or [],
        on_sale=model.on_sale,
        checked_at=model.checked_at,
        cheapshark_game_id=model.cheapshark_game_id,
        cheapest_price_ever=model.cheapest_price_ever,
        cheapest_price_ever_date=model.cheapest_price_ever_date,
    )


def _as_decimal(value: Decimal | None) -> Decimal | None:
    return value if value is None else Decimal(str(value))


async def get_game_price(session: AsyncSession, steam_app_id: int) -> GamePrice | None:
    model = await session.get(GamePriceModel, steam_app_id)
    return _to_schema(model) if model is not None else None


async def upsert_game_price(
    session: AsyncSession, params: UpsertGamePriceParams
) -> GamePrice:
    model = await session.get(GamePriceModel, params.steam_app_id)
    if model is None:
        model = GamePriceModel(steam_app_id=params.steam_app_id)
        session.add(model)

    model.cheapshark_game_id = params.cheapshark_game_id
    model.deals = params.deals
    model.cheapest_price_ever = _as_decimal(params.cheapest_price_ever)
    model.cheapest_price_ever_date = params.cheapest_price_ever_date
    model.on_sale = params.on_sale
    model.checked_at = params.checked_at

    await session.commit()
    await session.refresh(model)
    return _to_schema(model)


async def get_tracked_user_steam_app_id_pairs(
    session: AsyncSession, *, owned: bool | None = None
) -> list[tuple[int, int]]:
    """Distinct (UserID, SteamAppId) pairs tracked by any BacklogEntry -
    the sweep in price_service.check_prices_and_alert uses owned=False
    so it never alerts about a sale on a game the user already owns.
    Returns pairs rather than just Steam App IDs since alerts are sent
    per user (each user's own Discord webhook, deduped independently -
    see UserGamePriceAlert)."""
    query = select(BacklogEntryModel.user_id, BacklogEntryModel.steam_app_id).where(
        BacklogEntryModel.steam_app_id.is_not(None)
    )
    if owned is not None:
        query = query.where(BacklogEntryModel.owned == owned)
    result = await session.execute(query.distinct())
    return [(user_id, steam_app_id) for user_id, steam_app_id in result.all()]


async def get_title_for_steam_app_id(session: AsyncSession, steam_app_id: int) -> str | None:
    result = await session.execute(
        select(BacklogEntryModel.title)
        .where(BacklogEntryModel.steam_app_id == steam_app_id)
        .limit(1)
    )
    return result.scalar_one_or_none()

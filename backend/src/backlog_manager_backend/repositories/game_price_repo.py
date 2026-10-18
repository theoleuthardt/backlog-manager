from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.models.backlog_entry import BacklogEntry as BacklogEntryModel
from backlog_manager_backend.models.game_price import GamePrice as GamePriceModel
from backlog_manager_backend.schemas.game_price import GamePrice, UpsertGamePriceParams


def _to_schema(model: GamePriceModel) -> GamePrice:
    return GamePrice(
        steam_app_id=model.steam_app_id,
        checked_at=model.checked_at,
        currency=model.currency,
        current_retail=model.current_retail,
        current_keyshops=model.current_keyshops,
        historical_retail=model.historical_retail,
        historical_keyshops=model.historical_keyshops,
        url=model.url,
    )


async def get_game_price(session: AsyncSession, steam_app_id: int) -> GamePrice | None:
    model = await session.get(GamePriceModel, steam_app_id)
    return _to_schema(model) if model is not None else None


async def get_checked_at_by_steam_app_id(
    session: AsyncSession, steam_app_ids: set[int]
) -> dict[int, datetime]:
    """When each of the given Steam App IDs was last refreshed; IDs without a
    price row are absent."""
    result = await session.execute(
        select(GamePriceModel.steam_app_id, GamePriceModel.checked_at).where(
            GamePriceModel.steam_app_id.in_(steam_app_ids)
        )
    )
    return {steam_app_id: checked_at for steam_app_id, checked_at in result.all()}


async def upsert_game_price(session: AsyncSession, params: UpsertGamePriceParams) -> GamePrice:
    model = await session.get(GamePriceModel, params.steam_app_id)
    if model is None:
        model = GamePriceModel(steam_app_id=params.steam_app_id)
        session.add(model)

    model.currency = params.currency
    model.current_retail = params.current_retail
    model.current_keyshops = params.current_keyshops
    model.historical_retail = params.historical_retail
    model.historical_keyshops = params.historical_keyshops
    model.url = params.url
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


async def get_title_for_user_steam_app_id(
    session: AsyncSession, user_id: int, steam_app_id: int
) -> str | None:
    """The title this specific user gave their own entry for this Steam
    App ID - not just any user's, since two users tracking the same game
    can have typed different titles and an alert must quote the
    recipient's own."""
    result = await session.execute(
        select(BacklogEntryModel.title)
        .where(
            BacklogEntryModel.user_id == user_id,
            BacklogEntryModel.steam_app_id == steam_app_id,
        )
        .limit(1)
    )
    return result.scalar_one_or_none()

from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.models.user_game_price_alert import (
    UserGamePriceAlert as UserGamePriceAlertModel,
)
from backlog_manager_backend.utils import now_truncated_to_minute


async def get_last_alerted_price(
    session: AsyncSession, user_id: int, steam_app_id: int
) -> Decimal | None:
    model = await session.get(UserGamePriceAlertModel, (user_id, steam_app_id))
    return model.last_alerted_price if model is not None else None


async def set_last_alerted_price(
    session: AsyncSession, user_id: int, steam_app_id: int, price: Decimal
) -> None:
    model = await session.get(UserGamePriceAlertModel, (user_id, steam_app_id))
    if model is None:
        model = UserGamePriceAlertModel(user_id=user_id, steam_app_id=steam_app_id)
        session.add(model)
    model.last_alerted_price = price
    model.updated_at = now_truncated_to_minute()
    await session.commit()

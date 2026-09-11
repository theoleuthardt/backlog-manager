from decimal import Decimal

from sqlalchemy.dialects.postgresql import insert as pg_insert
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


async def try_claim_alert(
    session: AsyncSession, user_id: int, steam_app_id: int, price: Decimal
) -> bool:
    """Atomically claims the right to send one Discord alert for this
    (user, steam_app_id) at `price`. The upsert only changes a row when
    no prior alert exists yet or the previous LastAlertedPrice differs,
    so two overlapping sweeps racing on the same pair can't both see
    this return True - Postgres serializes the conflicting write, and
    only whichever transaction actually changed the row proceeds to
    notify. Call clear_last_alerted_price to revert a claim whose
    Discord send then fails, so a later sweep retries instead of never
    alerting again for this price."""
    stmt = pg_insert(UserGamePriceAlertModel).values(
        user_id=user_id,
        steam_app_id=steam_app_id,
        last_alerted_price=price,
        updated_at=now_truncated_to_minute(),
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[
            UserGamePriceAlertModel.user_id,
            UserGamePriceAlertModel.steam_app_id,
        ],
        set_={
            "LastAlertedPrice": stmt.excluded["LastAlertedPrice"],
            "UpdatedAt": stmt.excluded["UpdatedAt"],
        },
        where=UserGamePriceAlertModel.last_alerted_price != price,
    ).returning(UserGamePriceAlertModel.user_id)
    result = await session.execute(stmt)
    await session.commit()
    return result.first() is not None


async def clear_last_alerted_price(
    session: AsyncSession, user_id: int, steam_app_id: int
) -> None:
    model = await session.get(UserGamePriceAlertModel, (user_id, steam_app_id))
    if model is not None:
        await session.delete(model)
        await session.commit()

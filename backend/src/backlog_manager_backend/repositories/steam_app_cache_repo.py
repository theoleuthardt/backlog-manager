from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import SteamAppDetails
from backlog_manager_backend.models.steam_app_info import SteamAppInfo as SteamAppInfoModel
from backlog_manager_backend.utils import now_truncated_to_minute


async def get_fresh(
    session: AsyncSession, app_ids: list[int], max_age: timedelta
) -> dict[int, SteamAppDetails]:
    """The stored name and header image of each asked app that was resolved
    less than `max_age` ago; apps never resolved, or resolved longer ago,
    are absent."""
    if not app_ids:
        return {}
    oldest = now_truncated_to_minute() - max_age
    result = await session.execute(
        select(SteamAppInfoModel).where(
            SteamAppInfoModel.steam_app_id.in_(app_ids),
            SteamAppInfoModel.resolved_at >= oldest,
        )
    )
    return {
        model.steam_app_id: SteamAppDetails(name=model.name, header_image=model.header_image)
        for model in result.scalars()
    }


async def upsert_many(
    session: AsyncSession,
    details: dict[int, SteamAppDetails],
    resolved_at: datetime | None = None,
) -> None:
    """Stores the names, replacing what an app already had."""
    if not details:
        return
    when = resolved_at or now_truncated_to_minute()
    statement = insert(SteamAppInfoModel).values(
        [
            {
                "steam_app_id": app_id,
                "name": detail.name,
                "header_image": detail.header_image,
                "resolved_at": when,
            }
            for app_id, detail in details.items()
        ]
    )
    await session.execute(
        statement.on_conflict_do_update(
            index_elements=[SteamAppInfoModel.steam_app_id],
            set_={
                "Name": statement.excluded["Name"],
                "HeaderImage": statement.excluded["HeaderImage"],
                "ResolvedAt": statement.excluded["ResolvedAt"],
            },
        )
    )
    await session.commit()

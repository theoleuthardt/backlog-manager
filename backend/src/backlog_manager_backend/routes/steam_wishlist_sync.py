"""Automatic Steam wishlist sync: the hourly cron container calls
POST /api/steam/wishlist/auto-sync with the shared X-Cron-Secret (same
guard as /api/prices/check), and a user reads and dismisses the report of
what the sync changed through /api/user/steam/wishlist/sync-report."""

from datetime import datetime
from typing import Annotated

from litestar import Router, delete, get, post
from litestar.di import NamedDependency, Provide
from litestar.exceptions import NotAuthorizedException
from litestar.params import FromQuery, HeaderParameter
from litestar.status_codes import HTTP_200_OK
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.routes.prices import (
    CRON_SECRET_SECURITY_REQUIREMENT,
    require_valid_cron_secret,
)
from backlog_manager_backend.schemas.steam_wishlist_sync import SteamWishlistSyncReport
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import steam_wishlist_sync_service
from backlog_manager_backend.services.credentials import (
    resolve_igdb_credentials_or_none,
    resolve_steamgriddb_api_key_or_none,
)


def _credentials_for(user: User) -> tuple[str | None, tuple[str, str] | None]:
    return resolve_steamgriddb_api_key_or_none(user), resolve_igdb_credentials_or_none(user)


@post(
    "/api/steam/wishlist/auto-sync",
    status_code=HTTP_200_OK,
    security=CRON_SECRET_SECURITY_REQUIREMENT,
    raises=[NotAuthorizedException],
)
async def run_wishlist_auto_sync(
    x_cron_secret: Annotated[str | None, HeaderParameter(name="X-Cron-Secret", required=False)],
    db_session: NamedDependency[AsyncSession],
) -> steam_wishlist_sync_service.SyncSummary:
    require_valid_cron_secret(x_cron_secret)
    return await steam_wishlist_sync_service.sync_all(db_session, _credentials_for)


@get("/api/user/steam/wishlist/sync-report")
async def get_wishlist_sync_report(
    current_user: NamedDependency[User],
) -> SteamWishlistSyncReport:
    return current_user.steam_wishlist_sync_report or SteamWishlistSyncReport()


@delete("/api/user/steam/wishlist/sync-report", status_code=HTTP_200_OK)
async def dismiss_wishlist_sync_report(
    updated_at: FromQuery[datetime],
    current_user: NamedDependency[User],
    db_session: NamedDependency[AsyncSession],
) -> None:
    await steam_wishlist_sync_service.dismiss_report(db_session, current_user, updated_at)


steam_wishlist_sync_cron_router = Router(path="", route_handlers=[run_wishlist_auto_sync])

steam_wishlist_sync_router = Router(
    path="",
    route_handlers=[get_wishlist_sync_report, dismiss_wishlist_sync_report],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
)

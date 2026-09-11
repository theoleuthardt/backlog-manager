"""POST /api/prices/check is the only endpoint in this API not meant to
be called by a logged-in user - it's triggered by an external scheduler
(see docs/PRICE_TRACKING.md) to sweep every tracked, not-yet-owned
Steam App ID for sales and fire Discord alerts. Gated by a static
shared secret (X-Cron-Secret) rather than a user JWT, compared with
secrets.compare_digest to avoid a timing side-channel."""

import secrets
from typing import Annotated

from litestar import Router, post
from litestar.di import NamedDependency
from litestar.exceptions import NotAuthorizedException
from litestar.params import HeaderParameter
from litestar.status_codes import HTTP_200_OK
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.config import settings
from backlog_manager_backend.services import price_service

CRON_SECRET_SECURITY_REQUIREMENT = [{"CronSecret": []}]


def _require_valid_cron_secret(provided: str | None) -> None:
    if not settings.price_check_cron_secret or not provided:
        raise NotAuthorizedException("Missing or unconfigured cron secret")
    if not secrets.compare_digest(provided, settings.price_check_cron_secret):
        raise NotAuthorizedException("Invalid cron secret")


@post(
    "/api/prices/check",
    status_code=HTTP_200_OK,
    security=CRON_SECRET_SECURITY_REQUIREMENT,
    raises=[NotAuthorizedException],
)
async def check_prices(
    x_cron_secret: Annotated[
        str | None, HeaderParameter(name="X-Cron-Secret", required=False)
    ],
    db_session: NamedDependency[AsyncSession],
) -> dict[str, int]:
    _require_valid_cron_secret(x_cron_secret)
    alerts_sent = await price_service.check_prices_and_alert(db_session)
    return {"alerts_sent": alerts_sent}


price_check_router = Router(path="", route_handlers=[check_prices])

import asyncio
import contextlib

from litestar import Litestar
from litestar.config.cors import CORSConfig
from litestar.datastructures import ResponseHeader
from litestar.di import Provide
from litestar.openapi import OpenAPIConfig
from litestar.openapi.spec import Components, SecurityScheme

from backlog_manager_backend.bootstrap import bootstrap_initial_admin
from backlog_manager_backend.config import settings
from backlog_manager_backend.db import engine, provide_db_session
from backlog_manager_backend.routes.auth import login, login_verify, two_factor_router
from backlog_manager_backend.routes.backlog import backlog_router
from backlog_manager_backend.routes.backups import backup_router
from backlog_manager_backend.routes.csv import csv_router
from backlog_manager_backend.routes.games import (
    authenticated_games_router,
    get_steam_app_id,
)
from backlog_manager_backend.routes.health import health
from backlog_manager_backend.routes.images import proxy_image
from backlog_manager_backend.routes.prices import price_check_router
from backlog_manager_backend.routes.steam import steam_router
from backlog_manager_backend.routes.user import admin_user_router, user_router
from backlog_manager_backend.services import backup_service

MAX_REQUEST_BODY_BYTES = 10 * 1024 * 1024
HSTS_MAX_AGE_SECONDS = 60 * 60 * 24 * 365

_SECURITY_HEADERS = [
    ResponseHeader(name="X-Content-Type-Options", value="nosniff"),
    ResponseHeader(name="X-Frame-Options", value="DENY"),
    ResponseHeader(name="Referrer-Policy", value="no-referrer"),
    ResponseHeader(
        name="Strict-Transport-Security", value=f"max-age={HSTS_MAX_AGE_SECONDS}; includeSubDomains"
    ),
]


BACKUP_SCHEDULER_INTERVAL_SECONDS = 60 * 60


async def start_backup_scheduler(app: Litestar) -> None:
    if settings.backup_scheduler_enabled:
        app.state.backup_scheduler_task = asyncio.create_task(
            backup_service.run_scheduler(BACKUP_SCHEDULER_INTERVAL_SECONDS)
        )


async def stop_backup_scheduler(app: Litestar) -> None:
    task = getattr(app.state, "backup_scheduler_task", None)
    if task is not None:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


async def close_db_connection() -> None:
    await engine.dispose()


def _openapi_config() -> OpenAPIConfig:
    return OpenAPIConfig(
        title="Backlog Manager API",
        version="1.0.0",
        components=Components(
            security_schemes={
                "BearerAuth": SecurityScheme(type="http", scheme="bearer", bearer_format="JWT"),
                "CronSecret": SecurityScheme(
                    type="apiKey", name="X-Cron-Secret", security_scheme_in="header"
                ),
            }
        ),
    )


def create_app() -> Litestar:
    """A factory (rather than a bare module-level instance) so tests can
    get a fresh app - and, critically, a fresh rate-limit store - per
    test instead of sharing one across the whole test session.

    The frontend calls this API directly, cross-origin, with no Next.js
    proxy in front. `cors_config` leaves allow_credentials at its False
    default: auth is a Bearer token in the Authorization header, not a
    cookie, so the browser never needs to send credentials on a
    cross-origin request here.

    The OpenAPI schema (and its /schema routes) only exists when
    ENABLE_DOCS is set; scripts/dump_openapi_schema.py sets it itself to
    generate the frontend client's input."""
    return Litestar(
        route_handlers=[
            health,
            proxy_image,
            login,
            login_verify,
            two_factor_router,
            backlog_router,
            backup_router,
            user_router,
            admin_user_router,
            steam_router,
            csv_router,
            authenticated_games_router,
            get_steam_app_id,
            price_check_router,
        ],
        dependencies={"db_session": Provide(provide_db_session)},
        on_startup=[bootstrap_initial_admin, start_backup_scheduler],
        on_shutdown=[stop_backup_scheduler, close_db_connection],
        request_max_body_size=MAX_REQUEST_BODY_BYTES,
        response_headers=_SECURITY_HEADERS,
        cors_config=CORSConfig(
            allow_origins=settings.cors_allowed_origins_list,
            allow_methods=["GET", "POST", "PUT", "DELETE"],
            allow_headers=["Content-Type", "Authorization"],
        ),
        openapi_config=_openapi_config() if settings.enable_docs else None,
    )


app = create_app()

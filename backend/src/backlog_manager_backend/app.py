from litestar import Litestar
from litestar.config.cors import CORSConfig
from litestar.di import Provide
from litestar.openapi import OpenAPIConfig
from litestar.openapi.spec import Components, SecurityScheme

from backlog_manager_backend.bootstrap import bootstrap_initial_admin
from backlog_manager_backend.config import settings
from backlog_manager_backend.db import engine, provide_db_session
from backlog_manager_backend.routes.auth import login
from backlog_manager_backend.routes.backlog import backlog_router
from backlog_manager_backend.routes.health import health
from backlog_manager_backend.routes.user import admin_user_router, user_router


async def close_db_connection() -> None:
    await engine.dispose()


def create_app() -> Litestar:
    """A factory (rather than a bare module-level instance) so tests can
    get a fresh app - and, critically, a fresh rate-limit store - per
    test instead of sharing one across the whole test session."""
    return Litestar(
        route_handlers=[
            health,
            login,
            backlog_router,
            user_router,
            admin_user_router,
        ],
        dependencies={"db_session": Provide(provide_db_session)},
        on_startup=[bootstrap_initial_admin],
        on_shutdown=[close_db_connection],
        # The frontend calls this API directly, cross-origin - no Next.js
        # proxy in front. allow_credentials stays False (the default):
        # auth is a Bearer token in the Authorization header, not a
        # cookie, so the browser never needs to send credentials on a
        # cross-origin request here.
        cors_config=CORSConfig(
            allow_origins=settings.cors_allowed_origins_list,
            allow_methods=["GET", "POST", "PUT", "DELETE"],
            allow_headers=["Content-Type", "Authorization"],
        ),
        openapi_config=OpenAPIConfig(
            title="Backlog Manager API",
            version="1.0.0",
            components=Components(
                security_schemes={
                    "BearerAuth": SecurityScheme(type="http", scheme="bearer", bearer_format="JWT")
                }
            ),
        ),
    )


app = create_app()

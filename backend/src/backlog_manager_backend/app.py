from litestar import Litestar
from litestar.di import Provide

from backlog_manager_backend.bootstrap import bootstrap_initial_admin
from backlog_manager_backend.db import engine, provide_db_session
from backlog_manager_backend.routes.auth import login
from backlog_manager_backend.routes.backlog import backlog_router
from backlog_manager_backend.routes.games import (
    enriched_search,
    get_cover,
    get_game,
    get_game_time_to_beat,
    get_genre,
    get_platform,
    search_game,
)
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
            search_game,
            enriched_search,
            get_game,
            get_game_time_to_beat,
            get_platform,
            get_cover,
            get_genre,
        ],
        dependencies={"db_session": Provide(provide_db_session)},
        on_startup=[bootstrap_initial_admin],
        on_shutdown=[close_db_connection],
    )


app = create_app()

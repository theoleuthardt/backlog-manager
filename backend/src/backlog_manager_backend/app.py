from litestar import Litestar

from backlog_manager_backend.db import engine
from backlog_manager_backend.routes.health import health


async def close_db_connection() -> None:
    await engine.dispose()


app = Litestar(
    route_handlers=[health],
    on_shutdown=[close_db_connection],
)

from litestar import Litestar
from litestar.di import Provide

from backlog_manager_backend.db import engine, provide_db_session
from backlog_manager_backend.routes.auth import login, register
from backlog_manager_backend.routes.health import health


async def close_db_connection() -> None:
    await engine.dispose()


app = Litestar(
    route_handlers=[health, register, login],
    dependencies={"db_session": Provide(provide_db_session)},
    on_shutdown=[close_db_connection],
)

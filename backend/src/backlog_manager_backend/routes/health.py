import asyncio

import structlog
from litestar import Response, get
from litestar.status_codes import HTTP_200_OK, HTTP_503_SERVICE_UNAVAILABLE
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from backlog_manager_backend.db import engine

logger = structlog.get_logger()

DB_PROBE_TIMEOUT_SECONDS = 5


@get("/health")
async def health() -> Response:
    try:
        async with asyncio.timeout(DB_PROBE_TIMEOUT_SECONDS):
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
    except (SQLAlchemyError, TimeoutError) as exc:
        logger.error("health_check_db_failed", error=str(exc))
        return Response(
            {"status": "error", "database": "unreachable"},
            status_code=HTTP_503_SERVICE_UNAVAILABLE,
        )

    return Response(
        {"status": "ok", "database": "connected"},
        status_code=HTTP_200_OK,
    )

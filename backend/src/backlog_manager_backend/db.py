"""Database engine and session setup.

`NullPool` means the engine never caches a connection across calls. A
pooled connection opened under one asyncio event loop can't be safely
reused (or even closed) from a different loop - which happens routinely
across test runs (e.g. a sync-facing test client spinning up its own
loop). A real connection pool is worth reintroducing once this is under
sustained request load, not before."""

from collections.abc import AsyncGenerator

from sqlalchemy import NullPool
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from backlog_manager_backend.config import settings

engine: AsyncEngine = create_async_engine(settings.postgres_url, poolclass=NullPool)
async_session = async_sessionmaker(engine, expire_on_commit=False)


async def provide_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Litestar dependency: one session per request, committed implicitly
    by each repository call and closed once the request finishes."""
    async with async_session() as session:
        yield session

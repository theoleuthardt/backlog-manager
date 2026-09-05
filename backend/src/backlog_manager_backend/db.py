from sqlalchemy import NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from backlog_manager_backend.config import settings

# NullPool: never cache a connection across calls. A pooled connection
# opened under one asyncio event loop can't be safely reused (or even
# closed) from a different loop - which happens routinely across test
# runs (e.g. a sync-facing test client spinning up its own loop). A
# real connection pool is worth reintroducing once this is under
# sustained request load, not before.
engine: AsyncEngine = create_async_engine(settings.postgres_url, poolclass=NullPool)
async_session = async_sessionmaker(engine, expire_on_commit=False)

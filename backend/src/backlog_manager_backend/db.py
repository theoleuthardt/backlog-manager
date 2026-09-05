from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from backlog_manager_backend.config import settings

engine: AsyncEngine = create_async_engine(settings.postgres_url, pool_pre_ping=True)
async_session = async_sessionmaker(engine, expire_on_commit=False)

import os
from collections.abc import AsyncGenerator, Generator
from pathlib import Path

import asyncpg
import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from testcontainers.community.postgres import PostgresContainer

SCHEMA_SQL_PATH = Path(__file__).resolve().parents[2] / "postgres" / "backlogmanagerdb-init.sql"


@pytest.fixture(scope="session")
def postgres_url() -> Generator[str, None, None]:
    """Starts a real Postgres container for the test session, seeds the
    real schema (same file the frontend/CI use), and points the app's
    settings at it (must run before backlog_manager_backend.db is
    imported anywhere, since the engine is created at import time)."""
    # dbname matches the init SQL's hardcoded `ALTER DATABASE "backlog-manager-db"`
    with PostgresContainer("postgres:17-alpine", dbname="backlog-manager-db") as pg:
        os.environ["POSTGRES_URL"] = pg.get_connection_url().replace(
            "postgresql+psycopg2", "postgresql+asyncpg"
        )
        os.environ.setdefault("AUTH_SECRET", "test-only-secret-not-for-production")
        yield os.environ["POSTGRES_URL"]


@pytest.fixture(scope="session", autouse=True)
async def _seed_schema(postgres_url: str) -> None:
    dsn = postgres_url.replace("postgresql+asyncpg", "postgresql")
    conn = await asyncpg.connect(dsn)
    try:
        await conn.execute(SCHEMA_SQL_PATH.read_text())
    finally:
        await conn.close()


@pytest.fixture
async def session(_seed_schema: None) -> AsyncGenerator[AsyncSession, None]:
    """Function-scoped session, isolated from other tests: everything
    runs inside one connection-level transaction that's rolled back at
    the end, regardless of how many times repository code calls
    session.commit() (those become SAVEPOINTs via join_transaction_mode,
    not real commits) - the standard SQLAlchemy 2.0 per-test-rollback
    pattern, needed since the Postgres container is shared (session-
    scoped) for speed."""
    from sqlalchemy.ext.asyncio import async_sessionmaker

    from backlog_manager_backend.db import engine

    async with engine.connect() as connection:
        await connection.begin()
        test_session_factory = async_sessionmaker(
            bind=connection,
            join_transaction_mode="create_savepoint",
            expire_on_commit=False,
        )
        async with test_session_factory() as db_session:
            yield db_session
        await connection.rollback()

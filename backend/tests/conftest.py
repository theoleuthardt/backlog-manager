import os
from collections.abc import AsyncGenerator, Generator
from pathlib import Path

import asyncpg
import pytest
from cryptography.fernet import Fernet
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
        os.environ.setdefault("TOTP_ENCRYPTION_KEY", Fernet.generate_key().decode())
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


@pytest.fixture
def create_and_login(_seed_schema: None):
    """There is no public self-registration endpoint, so route-level
    tests (via a real TestClient hitting the app's own, separately
    committed session) need another way to seed a user: this creates
    one directly through the same service-layer function an admin's
    "create user" request would go through, then logs in for real over
    HTTP to get a token in the exact shape a client would receive."""

    async def _create_and_login(
        client, email: str, password: str = "hunter22", is_admin: bool = False
    ) -> dict[str, str]:
        from backlog_manager_backend.db import async_session
        from backlog_manager_backend.schemas.user import CreateUserRequest
        from backlog_manager_backend.services.auth_service import create_user

        async with async_session() as user_session:
            await create_user(
                user_session,
                CreateUserRequest(
                    username=email.split("@")[0],
                    email=email,
                    password=password,
                    is_admin=is_admin,
                ),
            )

        login_response = client.post("/api/auth/login", json={"email": email, "password": password})
        token = login_response.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}

    return _create_and_login

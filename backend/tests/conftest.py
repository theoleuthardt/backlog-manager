import os
from collections.abc import Generator

import pytest
from testcontainers.community.postgres import PostgresContainer


@pytest.fixture(scope="session")
def postgres_url() -> Generator[str, None, None]:
    """Starts a real Postgres container for the test session and points
    the app's settings at it (must run before backlog_manager_backend.db
    is imported anywhere, since the engine is created at import time)."""
    with PostgresContainer("postgres:17-alpine") as pg:
        url = pg.get_connection_url().replace("psycopg2", "asyncpg")
        os.environ["POSTGRES_URL"] = url
        yield url

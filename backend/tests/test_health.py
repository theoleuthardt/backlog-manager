from litestar.testing import AsyncTestClient


async def test_health_returns_ok_when_db_is_reachable(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    async with AsyncTestClient(app=app) as client:
        response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "connected"}

from litestar.testing import TestClient


def test_health_returns_ok_when_db_is_reachable(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "connected"}

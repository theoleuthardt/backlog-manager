from litestar.testing import TestClient


def test_register_then_login_returns_access_token(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        register_response = client.post(
            "/api/auth/register",
            json={
                "username": "routeuser",
                "email": "routeuser@example.com",
                "password": "hunter2",
            },
        )
        assert register_response.status_code == 201
        assert register_response.json()["email"] == "routeuser@example.com"
        assert "password_hash" not in register_response.json()

        login_response = client.post(
            "/api/auth/login",
            json={"email": "routeuser@example.com", "password": "hunter2"},
        )

    assert login_response.status_code == 200
    body = login_response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]


def test_register_rejects_duplicate_email(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        payload = {
            "username": "dupeuser",
            "email": "dupeuser@example.com",
            "password": "hunter2",
        }
        first = client.post("/api/auth/register", json=payload)
        second = client.post("/api/auth/register", json={**payload, "username": "dupeuser2"})

    assert first.status_code == 201
    assert second.status_code == 409


def test_login_rejects_wrong_password(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        client.post(
            "/api/auth/register",
            json={
                "username": "wrongpwroute",
                "email": "wrongpwroute@example.com",
                "password": "hunter2",
            },
        )
        login_response = client.post(
            "/api/auth/login",
            json={"email": "wrongpwroute@example.com", "password": "not-hunter2"},
        )

    assert login_response.status_code == 401

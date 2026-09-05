from litestar.testing import TestClient


async def test_login_returns_access_token_for_correct_credentials(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "routeuser@example.com")

    assert headers["Authorization"].startswith("Bearer ")


async def test_login_rejects_wrong_password(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        await create_and_login(client, "wrongpwroute@example.com", password="hunter22")
        login_response = client.post(
            "/api/auth/login",
            json={"email": "wrongpwroute@example.com", "password": "not-hunter22"},
        )

    assert login_response.status_code == 401


async def test_login_rejects_unknown_email(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        login_response = client.post(
            "/api/auth/login",
            json={"email": "nobody@example.com", "password": "hunter22"},
        )

    assert login_response.status_code == 401


def test_login_is_rate_limited(postgres_url: str) -> None:
    """Login is capped at 10 requests/minute per client (see
    routes/auth.py) - the highest-value brute-force target in the API.
    A fresh app per test (via create_app(), not the shared module-level
    singleton) means this doesn't interfere with other tests' login
    calls - see create_app()'s docstring."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        responses = [
            client.post("/api/auth/login", json={"email": "nobody@example.com", "password": "x"})
            for _ in range(11)
        ]

    assert responses[-1].status_code == 429

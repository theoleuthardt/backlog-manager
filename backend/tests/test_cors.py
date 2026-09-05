from litestar.testing import TestClient


def test_allows_configured_origin(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.options(
            "/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "Authorization, Content-Type",
            },
        )

    assert response.status_code == 204
    assert response.headers["access-control-allow-origin"] == "http://localhost:3000"
    allowed_headers = response.headers["access-control-allow-headers"].lower()
    assert "authorization" in allowed_headers
    assert "content-type" in allowed_headers


def test_rejects_unconfigured_origin(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.options(
            "/health",
            headers={
                "Origin": "https://evil.example",
                "Access-Control-Request-Method": "GET",
            },
        )

    assert "access-control-allow-origin" not in response.headers


def test_does_not_allow_credentials(postgres_url: str) -> None:
    """Auth is a Bearer token in the Authorization header, not a cookie -
    the browser never needs to send credentials cross-origin here, so
    Access-Control-Allow-Credentials must not be set."""
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.options(
            "/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )

    assert "access-control-allow-credentials" not in response.headers

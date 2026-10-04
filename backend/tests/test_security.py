import re
from types import SimpleNamespace

import pytest
from litestar.testing import TestClient


def _request(peer: str | None, headers: dict[str, str]) -> SimpleNamespace:
    client = SimpleNamespace(host=peer) if peer is not None else None
    return SimpleNamespace(client=client, headers=headers)


@pytest.fixture
def client_ip():
    from backlog_manager_backend.auth import client_ip as module

    return module


def test_client_ip_ignores_the_forwarded_header_without_trusted_proxies(
    client_ip, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(client_ip.settings, "trusted_proxy_ips", "")

    result = client_ip.get_client_ip(_request("172.18.0.5", {"cf-connecting-ip": "203.0.113.9"}))

    assert result == "172.18.0.5"


def test_client_ip_uses_the_forwarded_header_from_a_trusted_proxy(
    client_ip, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(client_ip.settings, "trusted_proxy_ips", "172.18.0.0/16")

    result = client_ip.get_client_ip(_request("172.18.0.5", {"cf-connecting-ip": "203.0.113.9"}))

    assert result == "203.0.113.9"


def test_client_ip_ignores_the_forwarded_header_from_an_untrusted_peer(
    client_ip, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(client_ip.settings, "trusted_proxy_ips", "172.18.0.0/16")

    result = client_ip.get_client_ip(_request("198.51.100.7", {"cf-connecting-ip": "203.0.113.9"}))

    assert result == "198.51.100.7"


def test_client_ip_falls_back_to_the_peer_when_a_trusted_proxy_sends_no_header(
    client_ip, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(client_ip.settings, "trusted_proxy_ips", "172.18.0.0/16")

    assert client_ip.get_client_ip(_request("172.18.0.5", {})) == "172.18.0.5"


def test_client_ip_falls_back_to_the_peer_when_the_forwarded_value_is_not_an_ip(
    client_ip, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(client_ip.settings, "trusted_proxy_ips", "172.18.0.0/16")

    result = client_ip.get_client_ip(_request("172.18.0.5", {"cf-connecting-ip": "not-an-ip"}))

    assert result == "172.18.0.5"


def test_client_ip_handles_a_request_without_a_peer(client_ip) -> None:
    assert client_ip.get_client_ip(_request(None, {})) == "unknown"


def test_login_rate_limit_cannot_be_dodged_by_spoofing_the_forwarded_header(
    postgres_url: str,
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        responses = [
            client.post(
                "/api/auth/login",
                json={"email": "nobody@example.com", "password": "x"},
                headers={"CF-Connecting-IP": f"203.0.113.{index}"},
            )
            for index in range(11)
        ]

    assert responses[-1].status_code == 429


def test_responses_carry_security_headers(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/health")

    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"
    assert "max-age=" in response.headers["strict-transport-security"]


async def test_login_responses_are_not_cacheable(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        await create_and_login(client, "nocache@example.com")
        response = client.post(
            "/api/auth/login",
            json={"email": "nocache@example.com", "password": "hunter2hunter2"},
        )

    assert "no-store" in response.headers["cache-control"]


def test_api_docs_are_not_served_by_default(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        responses = [
            client.get(path) for path in ("/schema", "/schema/swagger", "/schema/openapi.json")
        ]

    assert [response.status_code for response in responses] == [404, 404, 404]


def test_api_docs_are_served_when_enabled(
    postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "enable_docs", True)

    with TestClient(app=create_app()) as client:
        response = client.get("/schema/openapi.json")

    assert response.status_code == 200


def test_oversized_request_bodies_are_rejected(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    oversized = "x" * (11 * 1024 * 1024)

    with TestClient(app=create_app()) as client:
        response = client.post(
            "/api/auth/login", json={"email": "x@example.com", "password": oversized}
        )

    assert response.status_code == 413


async def test_every_admin_route_rejects_a_non_admin(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()
    admin_routes = [
        (method, re.sub(r"\{[^}]+\}", "1", route.path))
        for route in app.routes
        if route.path.startswith("/api/admin")
        for method in route.methods
        if method != "OPTIONS"
    ]
    assert admin_routes

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "notadmin@example.com")
        statuses = {
            (method, path): client.request(method, path, headers=headers, json={}).status_code
            for method, path in admin_routes
        }

    assert statuses == {key: 403 for key in statuses}


async def test_locked_account_rejects_the_correct_password_over_http(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        await create_and_login(client, "httplock@example.com")
        for _ in range(5):
            client.post(
                "/api/auth/login",
                json={"email": "httplock@example.com", "password": "wrong-password-1"},
            )
        response = client.post(
            "/api/auth/login",
            json={"email": "httplock@example.com", "password": "hunter2hunter2"},
        )

    assert response.status_code == 401


async def test_logout_all_invalidates_the_existing_token(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "logoutall@example.com")
        logout = client.post("/api/auth/logout-all", headers=headers)
        after = client.get("/api/user/me", headers=headers)
        relogin = client.post(
            "/api/auth/login",
            json={"email": "logoutall@example.com", "password": "hunter2hunter2"},
        )

    assert logout.status_code == 204
    assert after.status_code == 401
    assert relogin.status_code == 200


async def test_logout_all_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/auth/logout-all")

    assert response.status_code == 401


async def test_changing_the_own_password_invalidates_the_existing_token(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "pwrevoke@example.com")
        change = client.put("/api/user/me", headers=headers, json={"password": "another-long-pass"})
        after = client.get("/api/user/me", headers=headers)

    assert change.status_code == 200
    assert after.status_code == 401

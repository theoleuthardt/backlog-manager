from collections.abc import Callable

import httpx
import pytest
from litestar.testing import TestClient


def _mock_steam(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


def _configure_steam_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.routes import steam as steam_routes

    monkeypatch.setattr(steam_routes.settings, "steam_web_api_key", "server-api-key")


async def test_sync_steam_playtimes_updates_linked_entry(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["steamid"] == "76561197960287930"
        return httpx.Response(
            200,
            json={"response": {"games": [{"appid": 504230, "name": "Celeste", "playtime_forever": 510}]}},
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamsync@example.com")
        client.put(
            "/api/user/me", headers=headers, json={"steam_id": "76561197960287930"}
        )
        client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Celeste",
                "genre": ["Platformer"],
                "platform": ["PC"],
                "status": "In Progress",
                "owned": True,
                "interest": 8,
                "steam_app_id": 504230,
            },
        )

        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["title"] == "Celeste"
    assert body[0]["playtime"] == "8.50"


async def test_sync_steam_playtimes_requires_linked_account(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "nosteam@example.com")
        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 400


async def test_sync_steam_playtimes_returns_503_when_not_configured(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "unconfigured@example.com")
        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 503


async def test_sync_steam_playtimes_returns_503_on_transport_failure(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamdown@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 503


async def test_sync_steam_playtimes_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/user/steam/sync")

    assert response.status_code == 401

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


async def test_sync_steam_playtimes_prefers_users_own_key_over_server_fallback(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from cryptography.fernet import Fernet

    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import steam as steam_routes
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(steam_routes.settings, "steam_web_api_key", "server-api-key")
    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    used_keys: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        used_keys.append(request.url.params["key"])
        return httpx.Response(200, json={"response": {"games": []}})

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownsteamkey@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"steam_id": "76561197960287930", "steam_api_key": "users-own-key"},
        )

        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 200
    assert used_keys == ["users-own-key"]


async def test_sync_steam_playtimes_returns_503_on_undecryptable_stored_key(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from cryptography.fernet import Fernet

    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "rotatedkey@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"steam_id": "76561197960287930", "steam_api_key": "users-own-key"},
        )

        monkeypatch.setattr(
            user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
        )

        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 503


async def test_sync_steam_playtimes_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/user/steam/sync")

    assert response.status_code == 401


async def test_import_steam_library_creates_entries_for_new_owned_games(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "response": {
                    "games": [{"appid": 620, "name": "Portal 2", "playtime_forever": 120}]
                }
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamimport@example.com")
        client.put(
            "/api/user/me", headers=headers, json={"steam_id": "76561197960287930"}
        )

        response = client.post("/api/user/steam/import", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["title"] == "Portal 2"
    assert body[0]["steam_app_id"] == 620
    assert body[0]["status"] == "Not Started"
    assert body[0]["owned"] is True


async def test_import_steam_library_skips_already_linked_games(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "response": {
                    "games": [{"appid": 504230, "name": "Celeste", "playtime_forever": 510}]
                }
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamimportskip@example.com")
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

        response = client.post("/api/user/steam/import", headers=headers)

    assert response.status_code == 200
    assert response.json() == []


async def test_import_steam_library_requires_linked_account(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "noimport@example.com")
        response = client.post("/api/user/steam/import", headers=headers)

    assert response.status_code == 400


async def test_import_steam_library_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/user/steam/import")

    assert response.status_code == 401


async def test_sync_steam_playtimes_also_imports_new_games_when_auto_import_enabled(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)
    call_count = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal call_count
        call_count += 1
        return httpx.Response(
            200,
            json={
                "response": {
                    "games": [
                        {"appid": 504230, "name": "Celeste", "playtime_forever": 510},
                        {"appid": 620, "name": "Portal 2", "playtime_forever": 120},
                    ]
                }
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "autoimport@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"steam_id": "76561197960287930", "steam_auto_import_enabled": True},
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
    titles = {entry["title"] for entry in body}
    assert titles == {"Celeste", "Portal 2"}
    assert call_count == 1


@pytest.fixture(autouse=True)
def _reset_achievement_schema_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.services import steam_service

    monkeypatch.setattr(steam_service, "_achievement_schema_cache", {})


async def test_get_steam_achievements_returns_progress(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        if "GetPlayerAchievements" in request.url.path:
            return httpx.Response(
                200,
                json={
                    "playerstats": {
                        "success": True,
                        "achievements": [
                            {
                                "apiname": "ach_a",
                                "achieved": 1,
                                "unlocktime": 1000,
                                "name": "A",
                                "description": "desc a",
                            },
                            {"apiname": "ach_b", "achieved": 0, "unlocktime": 0, "name": "B"},
                        ],
                    }
                },
            )
        return httpx.Response(
            200,
            json={
                "game": {
                    "availableGameStats": {
                        "achievements": [
                            {
                                "name": "ach_a",
                                "displayName": "Achievement A",
                                "description": "Do the thing",
                                "icon": "https://example.com/a.jpg",
                            }
                        ]
                    }
                }
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "achievements@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.get(
            "/api/user/steam/achievements",
            headers=headers,
            params={"steam_app_id": 504230},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["unlocked"] == 1
    assert body["total"] == 2
    assert body["achievements"][0]["display_name"] == "Achievement A"
    assert body["achievements"][0]["icon"] == "https://example.com/a.jpg"


async def test_get_steam_achievements_requires_linked_account(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "noachievements@example.com")
        response = client.get(
            "/api/user/steam/achievements", headers=headers, params={"steam_app_id": 504230}
        )

    assert response.status_code == 400


async def test_get_steam_achievements_returns_503_when_not_configured(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "achievementsunconfigured@example.com")
        response = client.get(
            "/api/user/steam/achievements", headers=headers, params={"steam_app_id": 504230}
        )

    assert response.status_code == 503


async def test_get_steam_achievements_returns_503_on_transport_failure(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "achievementsdown@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.get(
            "/api/user/steam/achievements", headers=headers, params={"steam_app_id": 504230}
        )

    assert response.status_code == 503


async def test_get_steam_achievements_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/user/steam/achievements", params={"steam_app_id": 504230})

    assert response.status_code == 401


async def test_sync_steam_playtimes_does_not_import_when_auto_import_disabled(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "response": {
                    "games": [{"appid": 620, "name": "Portal 2", "playtime_forever": 120}]
                }
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "noautoimport@example.com")
        client.put(
            "/api/user/me", headers=headers, json={"steam_id": "76561197960287930"}
        )

        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 200
    assert response.json() == []

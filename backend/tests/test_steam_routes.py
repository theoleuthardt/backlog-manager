import json
from collections.abc import Callable

import httpx
import pytest
from litestar.testing import TestClient

from backlog_manager_backend.integrations.types import SteamAppDetails


def _parse_sse(body: str) -> list[tuple[str | None, str]]:
    """Splits a raw SSE response body into (event, data) pairs, mirroring
    how a browser's EventSource (or the frontend's manual fetch-based
    reader, since EventSource can't send an Authorization header) would
    see each message - messages are separated by a blank line, each
    made of `event: ...` / `data: ...` fields."""
    messages: list[tuple[str | None, str]] = []
    for raw_message in body.strip("\r\n").split("\r\n\r\n"):
        event: str | None = None
        data_lines: list[str] = []
        for line in raw_message.split("\r\n"):
            if line.startswith("event: "):
                event = line.removeprefix("event: ")
            elif line.startswith("data: "):
                data_lines.append(line.removeprefix("data: "))
        if data_lines:
            messages.append((event, "\n".join(data_lines)))
    return messages


def _mock_steam(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    def wrapped_handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "shared.akamai.steamstatic.com" and request.method == "HEAD":
            return httpx.Response(404, request=request)
        return handler(request)

    transport = httpx.MockTransport(wrapped_handler)

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
            json={
                "response": {
                    "games": [{"appid": 504230, "name": "Celeste", "playtime_forever": 510}]
                }
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamsync@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})
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
                "response": {"games": [{"appid": 620, "name": "Portal 2", "playtime_forever": 120}]}
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamimport@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

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
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})
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


async def test_import_steam_library_sets_cover_from_steamgriddb(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import steam as steam_routes

    _configure_steam_api_key(monkeypatch)
    monkeypatch.setattr(steam_routes.settings, "steamgriddb_api_key", "server-griddb-key")

    def handler(request: httpx.Request) -> httpx.Response:
        if "steamgriddb.com" in request.url.host:
            return httpx.Response(
                200,
                json={
                    "success": True,
                    "data": [
                        {
                            "id": 1,
                            "url": "https://cdn2.steamgriddb.com/grid/1.png",
                            "thumb": "https://cdn2.steamgriddb.com/thumb/1.png",
                            "score": 50,
                        }
                    ],
                },
            )
        return httpx.Response(
            200,
            json={
                "response": {"games": [{"appid": 620, "name": "Portal 2", "playtime_forever": 120}]}
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamimportcover@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.post("/api/user/steam/import", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["image_link"] == "https://cdn2.steamgriddb.com/grid/1.png"


async def test_import_steam_library_includes_family_members_games(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "hltbapi1.azurewebsites.net":
            return httpx.Response(200, json=[])
        steam_id = request.url.params["steamid"]
        if steam_id == "76561197960287930":
            games = [{"appid": 504230, "name": "Celeste", "playtime_forever": 510}]
        else:
            assert steam_id == "76561198000000001"
            games = [{"appid": 620, "name": "Portal 2", "playtime_forever": 999}]
        return httpx.Response(200, json={"response": {"games": games}})

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamfamilyimport@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={
                "steam_id": "76561197960287930",
                "steam_family_ids": "76561198000000001",
            },
        )

        response = client.post("/api/user/steam/import", headers=headers)

    assert response.status_code == 200
    body = response.json()
    titles_by_playtime = {entry["title"]: entry["playtime"] for entry in body}
    assert titles_by_playtime == {"Celeste": "8.50", "Portal 2": "0.00"}


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
    owned_games_call_count = 0

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "hltbapi1.azurewebsites.net":
            return httpx.Response(200, json=[])
        nonlocal owned_games_call_count
        owned_games_call_count += 1
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
    assert owned_games_call_count == 1


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


async def test_get_steam_achievements_response_is_not_cached(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        if "GetPlayerAchievements" in request.url.path:
            return httpx.Response(200, json={"playerstats": {"success": False}})
        return httpx.Response(200, json={"game": {}})

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "achievementscache@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.get(
            "/api/user/steam/achievements", headers=headers, params={"steam_app_id": 504230}
        )

    assert response.headers["cache-control"] == "no-store"


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
                "response": {"games": [{"appid": 620, "name": "Portal 2", "playtime_forever": 120}]}
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "noautoimport@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.post("/api/user/steam/sync", headers=headers)

    assert response.status_code == 200
    assert response.json() == []


async def test_import_steam_library_stream_reports_progress_then_done(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "hltbapi1.azurewebsites.net":
            return httpx.Response(200, json=[])
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
        headers = await create_and_login(client, "steamimportstream@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.post("/api/user/steam/import/stream", headers=headers)

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    messages = _parse_sse(response.text)

    progress_events = [json.loads(data) for event, data in messages if event == "progress"]
    assert progress_events == [
        {"processed": 1, "total": 2},
        {"processed": 2, "total": 2},
    ]

    done_events = [json.loads(data) for event, data in messages if event == "done"]
    assert len(done_events) == 1
    titles = {entry["title"] for entry in done_events[0]}
    assert titles == {"Celeste", "Portal 2"}


async def test_sync_steam_playtimes_stream_reports_progress_only_for_auto_import(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "hltbapi1.azurewebsites.net":
            return httpx.Response(200, json=[])
        return httpx.Response(
            200,
            json={
                "response": {"games": [{"appid": 620, "name": "Portal 2", "playtime_forever": 120}]}
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamsyncstream@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"steam_id": "76561197960287930", "steam_auto_import_enabled": True},
        )

        response = client.post("/api/user/steam/sync/stream", headers=headers)

    assert response.status_code == 200
    messages = _parse_sse(response.text)

    progress_events = [json.loads(data) for event, data in messages if event == "progress"]
    assert progress_events == [{"processed": 1, "total": 1}]

    done_events = [json.loads(data) for event, data in messages if event == "done"]
    assert len(done_events) == 1
    assert done_events[0][0]["title"] == "Portal 2"


async def test_sync_steam_playtimes_stream_sends_error_event_when_not_linked(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "nosteamstream@example.com")
        response = client.post("/api/user/steam/sync/stream", headers=headers)

    assert response.status_code == 200
    messages = _parse_sse(response.text)
    assert len(messages) == 1
    event, data = messages[0]
    assert event == "error"
    assert data == "Steam account is not linked"


async def test_sync_steam_playtimes_stream_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/user/steam/sync/stream")

    assert response.status_code == 401


async def test_preview_steam_wishlist_returns_items_without_writing(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.services import steam_service

    _configure_steam_api_key(monkeypatch)

    async def fake_preview_wishlist(
        db_session: object, user: object, key: object = None
    ) -> list[object]:
        from backlog_manager_backend.services.steam_service import SteamPreviewItem

        return [
            SteamPreviewItem(
                steam_app_id=620,
                title="Portal 2",
                image_link="https://cdn.cloudflare.steamstatic.com/steam/apps/620/capsule_sm_120.jpg",
            )
        ]

    monkeypatch.setattr(steam_service, "preview_wishlist", fake_preview_wishlist)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "wlpreview@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.get("/api/user/steam/wishlist/preview", headers=headers)
        entries = client.get("/api/backlog/entries", headers=headers).json()

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["steam_app_id"] == 620
    assert body[0]["title"] == "Portal 2"
    assert entries == []


async def test_preview_steam_wishlist_requires_linked_account(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "wlpreview404@example.com")
        response = client.get("/api/user/steam/wishlist/preview", headers=headers)

    assert response.status_code == 400


async def test_preview_steam_wishlist_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/user/steam/wishlist/preview")

    assert response.status_code == 401


async def test_import_steam_wishlist_stream_creates_not_owned_entries(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.services import steam_service

    _configure_steam_api_key(monkeypatch)

    async def fake_get_steam_app_details(app_ids: list[int]) -> dict[int, SteamAppDetails]:
        return {}

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_get_steam_app_details)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "wlimport@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.post(
            "/api/user/steam/wishlist/import/stream",
            headers=headers,
            json=[{"appid": 620, "priority": 0, "date_added": 1600000000}],
        )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    messages = _parse_sse(response.text)

    assert [json.loads(data) for event, data in messages if event == "progress"] == [
        {"processed": 1, "total": 1}
    ]

    done_events = [json.loads(data) for event, data in messages if event == "done"]
    assert len(done_events) == 1
    assert done_events[0][0]["title"].startswith("Steam App 620")
    assert done_events[0][0]["status"] == "Not Owned"


async def test_import_steam_wishlist_stream_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/user/steam/wishlist/import/stream", json=[{"appid": 620}])

    assert response.status_code == 401


async def test_import_steam_wishlist_stream_rejects_non_positive_appid(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "wlappid@example.com")
        response = client.post(
            "/api/user/steam/wishlist/import/stream",
            headers=headers,
            json=[{"appid": 0}],
        )

    assert response.status_code == 400
    assert "steam app ids must be 1 or greater" in response.json()["detail"]


async def test_import_steam_wishlist_stream_rejects_oversized_list(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes.steam import _WISHLIST_IMPORT_MAX_ITEMS

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "wlmax@example.com")
        response = client.post(
            "/api/user/steam/wishlist/import/stream",
            headers=headers,
            json=[{"appid": 620}] * (_WISHLIST_IMPORT_MAX_ITEMS + 1),
        )

    assert response.status_code == 400
    assert "limited to" in response.json()["detail"]


async def test_import_steam_library_stream_rejects_non_positive_appid(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "libappid@example.com")
        response = client.post(
            "/api/user/steam/import/stream",
            headers=headers,
            json=[{"appid": -1}],
        )

    assert response.status_code == 400
    assert "steam app ids must be 1 or greater" in response.json()["detail"]


async def test_import_steam_library_stream_restricts_to_confirmed_app_ids(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The confirmed appids from the preview bind the import: a game that
    joined the Steam library after the preview must not be imported."""
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "hltbapi1.azurewebsites.net":
            return httpx.Response(200, json=[])
        return httpx.Response(
            200,
            json={
                "response": {
                    "games": [
                        {"appid": 620, "name": "Portal 2", "playtime_forever": 120},
                        {"appid": 504230, "name": "Celeste", "playtime_forever": 510},
                    ]
                }
            },
        )

    _mock_steam(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "libconfirmed@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.post(
            "/api/user/steam/import/stream",
            headers=headers,
            json=[{"appid": 504230}],
        )
        titles = [
            entry["title"] for entry in client.get("/api/backlog/entries", headers=headers).json()
        ]

    assert response.status_code == 200
    messages = _parse_sse(response.text)
    done_events = [json.loads(data) for event, data in messages if event == "done"]
    assert [entry["title"] for entry in done_events[0]] == ["Celeste"]
    assert titles == ["Celeste"]


async def test_import_steam_wishlist_stream_sends_error_when_not_linked(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "wlimport400@example.com")
        response = client.post(
            "/api/user/steam/wishlist/import/stream",
            headers=headers,
            json=[{"appid": 620}],
        )

    assert response.status_code == 200
    messages = _parse_sse(response.text)
    assert messages == [("error", "Steam account is not linked")]


async def test_preview_steam_library_stream_lists_unlinked_games(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.services import steam_service

    _configure_steam_api_key(monkeypatch)

    async def fake_preview_library(
        db_session: object,
        user: object,
        api_key: str,
        steamgriddb_api_key: str | None = None,
        on_progress: object | None = None,
        family_steam_ids: list[str] | None = None,
    ) -> list[object]:
        from backlog_manager_backend.services.steam_service import SteamPreviewItem

        if on_progress:
            await on_progress(1, 1)
        return [
            SteamPreviewItem(
                steam_app_id=620,
                title="Portal 2",
                image_link="https://cdn2.steamgriddb.com/grid/1.png",
            )
        ]

    monkeypatch.setattr(steam_service, "preview_library", fake_preview_library)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "libpreview@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_id": "76561197960287930"})

        response = client.post("/api/user/steam/library/preview/stream", headers=headers)
        entries = client.get("/api/backlog/entries", headers=headers).json()

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    messages = _parse_sse(response.text)

    assert [json.loads(data) for event, data in messages if event == "progress"] == [
        {"processed": 1, "total": 1}
    ]
    done_events = [json.loads(data) for event, data in messages if event == "done"]
    assert done_events == [
        [
            {
                "steam_app_id": 620,
                "title": "Portal 2",
                "image_link": "https://cdn2.steamgriddb.com/grid/1.png",
            }
        ]
    ]
    assert entries == []


async def test_preview_steam_library_stream_sends_error_when_not_linked(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_steam_api_key(monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "libpreview400@example.com")
        response = client.post("/api/user/steam/library/preview/stream", headers=headers)

    assert response.status_code == 200
    messages = _parse_sse(response.text)
    assert messages == [("error", "Steam account is not linked")]


async def test_preview_steam_library_stream_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/user/steam/library/preview/stream")

    assert response.status_code == 401

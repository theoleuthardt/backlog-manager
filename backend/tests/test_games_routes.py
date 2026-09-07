from collections.abc import Callable
from types import ModuleType

import httpx
import pytest
from litestar.testing import TestClient


@pytest.fixture
def configured_igdb(monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    """Imported lazily - see test_game_service.py's game_service fixture
    for why (services.game_service -> config eagerly builds Settings()
    on import)."""
    from backlog_manager_backend.services import game_service as module

    monkeypatch.setattr(module, "_cached_token", None)
    monkeypatch.setattr(module, "_genre_cache", {})
    monkeypatch.setattr(module, "_platform_cache", {})
    monkeypatch.setattr(module, "_game_cache", {})
    monkeypatch.setattr(module, "_cover_cache", {})
    monkeypatch.setattr(module, "_time_to_beat_cache", {})
    monkeypatch.setattr(module.settings, "igdb_client_id", "cid")
    monkeypatch.setattr(module.settings, "igdb_client_secret", "secret")
    return module


def _mock_igdb(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


def _token_or(data_response: object) -> Callable[[httpx.Request], httpx.Response]:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "id.twitch.tv":
            return httpx.Response(
                200, json={"access_token": "tok", "expires_in": 3600, "token_type": "bearer"}
            )
        return httpx.Response(200, json=data_response)

    return handler


async def test_search_game(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    _mock_igdb(_token_or([{"id": 1, "name": "Zelda", "game": 1}]), monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/search", params={"search_term": "Zelda"})

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["id"] == 1
    assert body[0]["name"] == "Zelda"
    assert body[0]["game"] == 1


async def test_search_game_requires_search_term(
    configured_igdb: ModuleType, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/search")

    assert response.status_code == 400


async def test_search_game_returns_503_when_igdb_not_configured(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/search", params={"search_term": "Zelda"})

    assert response.status_code == 503


async def test_get_game(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    _mock_igdb(_token_or([{"id": 141503, "name": "Hollow Knight"}]), monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/141503")

    assert response.status_code == 200
    assert response.json()[0]["name"] == "Hollow Knight"


async def test_get_game_time_to_beat(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    _mock_igdb(_token_or([{"id": 1, "game_id": 141503, "normally": 3600}]), monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/141503/time-to-beat")

    assert response.status_code == 200
    assert response.json()[0]["game_id"] == 141503


async def test_get_platform(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    _mock_igdb(_token_or([{"id": 169, "name": "PC (Microsoft Windows)"}]), monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/platforms/169")

    assert response.status_code == 200
    assert response.json()[0]["name"] == "PC (Microsoft Windows)"


async def test_get_cover(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    _mock_igdb(_token_or([{"id": 1, "image_id": "abc123"}]), monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/covers/1")

    assert response.status_code == 200
    assert response.json()[0]["image_id"] == "abc123"


async def test_get_genre(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    _mock_igdb(_token_or([{"id": 10, "name": "Adventure"}]), monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/genres/10")

    assert response.status_code == 200
    assert response.json()[0]["name"] == "Adventure"


async def test_enriched_search(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "id.twitch.tv":
            return httpx.Response(
                200, json={"access_token": "tok", "expires_in": 3600, "token_type": "bearer"}
            )
        if request.url.path == "/v4/search":
            return httpx.Response(200, json=[{"id": 1, "game": 1, "name": "Celeste"}])
        if request.url.path == "/v4/games":
            return httpx.Response(
                200, json=[{"id": 1, "name": "Celeste", "cover": 5, "genres": [], "platforms": []}]
            )
        if request.url.path == "/v4/covers":
            return httpx.Response(200, json=[{"id": 5, "image_id": "cover123"}])
        if request.url.path == "/v4/game_time_to_beats":
            return httpx.Response(200, json=[{"id": 1, "game_id": 1, "normally": 3600}])
        raise AssertionError(f"unexpected request: {request.url}")

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/enriched-search", params={"search_term": "Celeste"})

    assert response.status_code == 200
    body = response.json()
    assert body[0]["title"] == "Celeste"
    assert (
        body[0]["image_url"] == "https://images.igdb.com/igdb/image/upload/t_cover_big/cover123.jpg"
    )


async def test_enriched_search_batches_multiple_results(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    """End-to-end regression test for issue #105 through the real route:
    2 search results must only hit each IGDB endpoint once, not once per
    result."""
    from backlog_manager_backend.app import create_app

    call_counts: dict[str, int] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "id.twitch.tv":
            return httpx.Response(
                200, json={"access_token": "tok", "expires_in": 3600, "token_type": "bearer"}
            )
        call_counts[request.url.path] = call_counts.get(request.url.path, 0) + 1
        if request.url.path == "/v4/search":
            return httpx.Response(
                200,
                json=[
                    {"id": 1, "game": 1, "name": "Celeste"},
                    {"id": 2, "game": 2, "name": "Hollow Knight"},
                ],
            )
        if request.url.path == "/v4/games":
            return httpx.Response(
                200,
                json=[
                    {"id": 1, "name": "Celeste", "cover": 5, "genres": [10], "platforms": [6]},
                    {"id": 2, "name": "Hollow Knight", "cover": 8, "genres": [10], "platforms": [6]},
                ],
            )
        if request.url.path == "/v4/covers":
            return httpx.Response(
                200, json=[{"id": 5, "image_id": "abc"}, {"id": 8, "image_id": "def"}]
            )
        if request.url.path == "/v4/genres":
            return httpx.Response(200, json=[{"id": 10, "name": "Platformer"}])
        if request.url.path == "/v4/platforms":
            return httpx.Response(200, json=[{"id": 6, "name": "PC"}])
        if request.url.path == "/v4/game_time_to_beats":
            return httpx.Response(
                200,
                json=[
                    {"id": 1, "game_id": 1, "normally": 3600},
                    {"id": 2, "game_id": 2, "normally": 7200},
                ],
            )
        raise AssertionError(f"unexpected request: {request.url}")

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/enriched-search", params={"search_term": "metroidvania"})

    assert response.status_code == 200
    assert len(response.json()) == 2
    assert call_counts == {
        "/v4/search": 1,
        "/v4/games": 1,
        "/v4/covers": 1,
        "/v4/genres": 1,
        "/v4/platforms": 1,
        "/v4/game_time_to_beats": 1,
    }


async def test_enriched_search_returns_503_when_igdb_not_configured(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/enriched-search", params={"search_term": "Celeste"})

    assert response.status_code == 503


async def test_search_game_returns_503_on_transport_failure(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    """Regression test: a connection failure during the actual IGDB data
    query (after a token was already obtained) used to propagate
    uncaught as httpx.RequestError, becoming a generic 500 instead of
    503."""
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "id.twitch.tv":
            return httpx.Response(
                200, json={"access_token": "tok", "expires_in": 3600, "token_type": "bearer"}
            )
        raise httpx.ConnectError("connection refused", request=request)

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/search", params={"search_term": "Zelda"})

    assert response.status_code == 503


async def test_search_game_returns_503_when_token_request_fails(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    """Same failure class, one step earlier: a transport failure while
    acquiring the IGDB access token itself."""
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/search", params={"search_term": "Zelda"})

    assert response.status_code == 503


async def test_enriched_search_returns_503_on_transport_failure(
    configured_igdb: ModuleType, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "id.twitch.tv":
            return httpx.Response(
                200, json={"access_token": "tok", "expires_in": 3600, "token_type": "bearer"}
            )
        raise httpx.ConnectError("connection refused", request=request)

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/enriched-search", params={"search_term": "Celeste"})

    assert response.status_code == 503


@pytest.fixture
def _reset_steam_app_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.services import game_service as module

    monkeypatch.setattr(module, "_steam_app_id_by_title", {})
    monkeypatch.setattr(module, "_steam_app_list_cached_at", None)


async def test_get_steam_app_id_matches_by_title(
    _reset_steam_app_cache: None, postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200, json={"applist": {"apps": [{"appid": 504230, "name": "Celeste"}]}}
        )

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/steam-app-id", params={"title": "Celeste"})

    assert response.status_code == 200
    assert response.json() == 504230


async def test_get_steam_app_id_returns_null_when_no_match(
    _reset_steam_app_cache: None, postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"applist": {"apps": []}})

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/games/steam-app-id", params={"title": "Some Unreleased Game"}
        )

    assert response.status_code == 200
    assert response.json() is None


@pytest.fixture
def _reset_steamgriddb_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.services import game_service as module

    monkeypatch.setattr(module, "_steamgriddb_cover_cache", {})


async def test_get_steamgriddb_covers_returns_urls(
    _reset_steamgriddb_cache: None, postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.services import game_service as module

    monkeypatch.setattr(module.settings, "steamgriddb_api_key", "key")

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "success": True,
                "data": [
                    {
                        "id": 1,
                        "url": "https://cdn2.steamgriddb.com/grid/1.png",
                        "thumb": "https://cdn2.steamgriddb.com/thumb/1.png",
                        "score": 10,
                    }
                ],
            },
        )

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/games/steamgriddb-covers", params={"steam_app_id": 220}
        )

    assert response.status_code == 200
    assert response.json() == ["https://cdn2.steamgriddb.com/grid/1.png"]


async def test_get_steamgriddb_covers_returns_503_when_not_configured(
    _reset_steamgriddb_cache: None, postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.services import game_service as module

    monkeypatch.setattr(module.settings, "steamgriddb_api_key", None)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/games/steamgriddb-covers", params={"steam_app_id": 220}
        )

    assert response.status_code == 503


async def test_get_steamgriddb_covers_returns_503_on_transport_failure(
    _reset_steamgriddb_cache: None, postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.services import game_service as module

    monkeypatch.setattr(module.settings, "steamgriddb_api_key", "key")

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/games/steamgriddb-covers", params={"steam_app_id": 220}
        )

    assert response.status_code == 503


async def test_get_steam_app_id_returns_null_on_transport_failure(
    _reset_steam_app_cache: None, postgres_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _mock_igdb(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/steam-app-id", params={"title": "Celeste"})

    assert response.status_code == 200
    assert response.json() is None

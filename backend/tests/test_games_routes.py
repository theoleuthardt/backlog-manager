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
            return httpx.Response(200, json=[{"id": 1, "normally": 3600}])
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


async def test_enriched_search_returns_503_when_igdb_not_configured(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/enriched-search", params={"search_term": "Celeste"})

    assert response.status_code == 503

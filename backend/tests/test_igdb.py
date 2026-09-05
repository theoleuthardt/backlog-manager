from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.igdb import (
    generate_igdb_token,
    get_genre_on_igdb,
    search_game_on_igdb,
)


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


async def test_generate_igdb_token_returns_parsed_token(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "id.twitch.tv"
        assert request.url.params["client_id"] == "cid"
        assert request.url.params["client_secret"] == "secret"
        return httpx.Response(
            200, json={"access_token": "tok", "expires_in": 3600, "token_type": "bearer"}
        )

    _mock_client(handler, monkeypatch)

    token = await generate_igdb_token("cid", "secret")

    assert token.access_token == "tok"
    assert token.expires_in == 3600


async def test_generate_igdb_token_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(401)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await generate_igdb_token("cid", "bad-secret")


async def test_search_game_on_igdb_sends_authorization_headers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v4/search"
        assert request.headers["Authorization"] == "Bearer tok"
        assert request.headers["Client-ID"] == "cid"
        assert "Zelda" in request.content.decode()
        return httpx.Response(200, json=[{"id": 1, "name": "Zelda", "game": 42}])

    _mock_client(handler, monkeypatch)

    results = await search_game_on_igdb("Zelda", "cid", "tok")

    assert len(results) == 1
    assert results[0].game == 42


async def test_search_game_on_igdb_escapes_quotes_in_search_term(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, bytes] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["body"] = request.content
        return httpx.Response(200, json=[])

    _mock_client(handler, monkeypatch)

    await search_game_on_igdb('quote " injection', "cid", "tok")

    assert b'\\"' in captured["body"]


async def test_search_game_on_igdb_returns_empty_list_on_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(429)

    _mock_client(handler, monkeypatch)

    assert await search_game_on_igdb("Zelda", "cid", "tok") == []


async def test_get_genre_on_igdb_returns_parsed_genre(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v4/genres"
        return httpx.Response(200, json=[{"id": 10, "name": "Adventure"}])

    _mock_client(handler, monkeypatch)

    genres = await get_genre_on_igdb(10, "cid", "tok")

    assert genres[0].name == "Adventure"

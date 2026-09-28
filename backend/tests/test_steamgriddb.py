from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.steamgriddb import (
    get_grids_by_steam_app_id,
    get_grids_by_steamgriddb_id,
    search_steamgriddb_games,
)

_SAMPLE_RESPONSE = {
    "success": True,
    "data": [
        {
            "id": 1,
            "url": "https://cdn2.steamgriddb.com/grid/1.png",
            "thumb": "https://cdn2.steamgriddb.com/thumb/1.png",
            "score": 50,
        },
        {
            "id": 2,
            "url": "https://cdn2.steamgriddb.com/grid/2.png",
            "thumb": "https://cdn2.steamgriddb.com/thumb/2.png",
            "score": 90,
        },
    ],
}


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


async def test_get_grids_by_steam_app_id_returns_parsed_results(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v2/grids/steam/220"
        assert request.headers["Authorization"] == "Bearer api-key"
        assert request.url.params["dimensions"] == "600x900,342x482"
        return httpx.Response(200, json=_SAMPLE_RESPONSE)

    _mock_client(handler, monkeypatch)

    grids = await get_grids_by_steam_app_id(220, "api-key")

    assert len(grids) == 2
    assert grids[0].id == 1
    assert grids[0].url == "https://cdn2.steamgriddb.com/grid/1.png"
    assert grids[0].score == 50


async def test_get_grids_by_steam_app_id_returns_empty_list_on_404(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404, json={"success": False, "errors": ["Not found"]})

    _mock_client(handler, monkeypatch)

    assert await get_grids_by_steam_app_id(999999, "api-key") == []


async def test_get_grids_by_steam_app_id_returns_empty_list_when_unsuccessful(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"success": False})

    _mock_client(handler, monkeypatch)

    assert await get_grids_by_steam_app_id(220, "api-key") == []


async def test_get_grids_by_steam_app_id_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_grids_by_steam_app_id(220, "bad-key")


async def test_get_grids_by_steam_app_id_raises_on_malformed_json(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not json")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_grids_by_steam_app_id(220, "api-key")


async def test_get_grids_by_steam_app_id_raises_on_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_grids_by_steam_app_id(220, "api-key")


async def test_get_grids_by_steamgriddb_id_returns_parsed_results(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v2/grids/game/5000"
        assert request.headers["Authorization"] == "Bearer api-key"
        assert request.url.params["dimensions"] == "600x900,342x482"
        return httpx.Response(200, json=_SAMPLE_RESPONSE)

    _mock_client(handler, monkeypatch)

    grids = await get_grids_by_steamgriddb_id(5000, "api-key")

    assert len(grids) == 2
    assert grids[0].url == "https://cdn2.steamgriddb.com/grid/1.png"


async def test_get_grids_by_steamgriddb_id_returns_empty_list_on_404(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404, json={"success": False, "errors": ["Not found"]})

    _mock_client(handler, monkeypatch)

    assert await get_grids_by_steamgriddb_id(999999, "api-key") == []


async def test_search_steamgriddb_games_returns_parsed_results(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v2/search/autocomplete/En Garde!"
        assert request.headers["Authorization"] == "Bearer api-key"
        return httpx.Response(
            200,
            json={
                "success": True,
                "data": [
                    {"id": 1, "name": "En Garde!"},
                    {"id": 2, "name": "En Garde! Student Project"},
                ],
            },
        )

    _mock_client(handler, monkeypatch)

    results = await search_steamgriddb_games("En Garde!", "api-key")

    assert len(results) == 2
    assert results[0].id == 1
    assert results[0].name == "En Garde!"


async def test_search_steamgriddb_games_encodes_slash_in_term(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A title like "Ori and the Blind Forest: Definitive Edition/GOTY"
    must have its `/` percent-encoded - otherwise it's indistinguishable
    from a literal path separator and would split the request path."""

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.raw_path == b"/api/v2/search/autocomplete/AC%2FDC"
        return httpx.Response(200, json={"success": True, "data": []})

    _mock_client(handler, monkeypatch)

    await search_steamgriddb_games("AC/DC", "api-key")


async def test_search_steamgriddb_games_returns_empty_list_when_unsuccessful(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"success": False})

    _mock_client(handler, monkeypatch)

    assert await search_steamgriddb_games("nonexistent", "api-key") == []


async def test_search_steamgriddb_games_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await search_steamgriddb_games("term", "bad-key")

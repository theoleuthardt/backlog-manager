from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.steamgriddb import get_grids_by_steam_app_id

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

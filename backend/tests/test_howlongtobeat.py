from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.howlongtobeat import (
    get_game_by_id_on_hltb,
    search_game_on_hltb,
)

_SAMPLE_RESULT = {
    "id": 1,
    "hltbId": 1,
    "title": "Celeste",
    "imageUrl": "https://example.com/celeste.jpg",
    "steamAppId": 504230,
    "gogAppId": None,
    "mainStory": 8.5,
    "mainStoryWithExtras": 12.0,
    "completionist": 37.0,
    "lastUpdatedAt": "2024-01-01",
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


async def test_search_game_on_hltb_returns_parsed_results(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/hltb/search"
        return httpx.Response(200, json=[_SAMPLE_RESULT])

    _mock_client(handler, monkeypatch)

    results = await search_game_on_hltb("Celeste")

    assert len(results) == 1
    assert results[0].title == "Celeste"
    assert results[0].main_story == 8.5
    assert results[0].steam_app_id == 504230


async def test_search_game_on_hltb_returns_empty_list_on_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    _mock_client(handler, monkeypatch)

    assert await search_game_on_hltb("Celeste") == []


async def test_search_game_on_hltb_returns_empty_list_on_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    assert await search_game_on_hltb("Celeste") == []


async def test_get_game_by_id_on_hltb_returns_parsed_result(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/hltb/1"
        return httpx.Response(200, json=_SAMPLE_RESULT)

    _mock_client(handler, monkeypatch)

    result = await get_game_by_id_on_hltb(1)

    assert result.title == "Celeste"


async def test_get_game_by_id_on_hltb_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_game_by_id_on_hltb(999)

from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.steam import get_owned_games

_SAMPLE_RESPONSE = {
    "response": {
        "game_count": 2,
        "games": [
            {"appid": 504230, "name": "Celeste", "playtime_forever": 510},
            {"appid": 220, "name": "Half-Life 2", "playtime_forever": 0},
        ],
    }
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


async def test_get_owned_games_returns_parsed_results(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["key"] == "api-key"
        assert request.url.params["steamid"] == "1234"
        return httpx.Response(200, json=_SAMPLE_RESPONSE)

    _mock_client(handler, monkeypatch)

    games = await get_owned_games("1234", "api-key")

    assert len(games) == 2
    assert games[0].appid == 504230
    assert games[0].name == "Celeste"
    assert games[0].playtime_forever == 510


async def test_get_owned_games_returns_empty_list_when_games_omitted(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"response": {}})

    _mock_client(handler, monkeypatch)

    assert await get_owned_games("1234", "api-key") == []


async def test_get_owned_games_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_owned_games("1234", "bad-key")


async def test_get_owned_games_raises_on_malformed_json(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not json")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_owned_games("1234", "api-key")


async def test_get_owned_games_raises_on_schema_mismatch(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"response": {"games": [{"appid": "not-an-int"}]}})

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_owned_games("1234", "api-key")


async def test_get_owned_games_raises_on_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_owned_games("1234", "api-key")

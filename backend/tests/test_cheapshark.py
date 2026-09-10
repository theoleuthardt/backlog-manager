from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.cheapshark import (
    find_cheapshark_game_id,
    get_cheapshark_game_detail,
    get_stores,
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


async def test_find_cheapshark_game_id_returns_first_match(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/1.0/games"
        assert request.url.params["steamAppID"] == "220"
        return httpx.Response(
            200,
            json=[{"gameID": "612", "steamAppID": "220"}],
        )

    _mock_client(handler, monkeypatch)

    assert await find_cheapshark_game_id(220) == 612


async def test_find_cheapshark_game_id_returns_none_when_no_match(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=[])

    _mock_client(handler, monkeypatch)

    assert await find_cheapshark_game_id(999999) is None


async def test_find_cheapshark_game_id_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await find_cheapshark_game_id(220)


async def test_get_cheapshark_game_detail_returns_parsed_result(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/1.0/games"
        assert request.url.params["id"] == "612"
        return httpx.Response(
            200,
            json={
                "info": {"title": "Half-Life 2", "steamAppID": "220"},
                "cheapestPriceEver": {"price": "2.99", "date": 1234567890},
                "deals": [
                    {
                        "storeID": "1",
                        "dealID": "abc123",
                        "price": "2.99",
                        "retailPrice": "9.99",
                        "savings": "70.000000",
                    }
                ],
            },
        )

    _mock_client(handler, monkeypatch)

    detail = await get_cheapshark_game_detail(612)

    assert detail.info.title == "Half-Life 2"
    assert detail.cheapestPriceEver.price == "2.99"
    assert len(detail.deals) == 1
    assert detail.deals[0].storeID == "1"
    assert detail.deals[0].dealID == "abc123"


async def test_get_cheapshark_game_detail_raises_on_malformed_json(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not json")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_cheapshark_game_detail(612)


async def test_get_cheapshark_game_detail_raises_on_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_cheapshark_game_detail(612)


async def test_get_stores_returns_parsed_results(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/1.0/stores"
        return httpx.Response(
            200,
            json=[
                {
                    "storeID": "1",
                    "storeName": "Steam",
                    "isActive": 1,
                    "images": {
                        "banner": "/img/stores/banners/0.png",
                        "logo": "/img/stores/logos/0.png",
                        "icon": "/img/stores/icons/0.png",
                    },
                }
            ],
        )

    _mock_client(handler, monkeypatch)

    stores = await get_stores()

    assert len(stores) == 1
    assert stores[0].storeName == "Steam"
    assert stores[0].images.icon == "/img/stores/icons/0.png"

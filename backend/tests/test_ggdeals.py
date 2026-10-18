import logging
from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.ggdeals import get_prices_by_steam_app_ids

_KEY = "secret-key-123"


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


def _body() -> dict:
    return {
        "success": True,
        "data": {
            "220": {
                "title": "Half-Life 2",
                "url": "https://gg.deals/game/half-life-2/",
                "prices": {
                    "currentRetail": "9.99",
                    "currentKeyshops": "4.50",
                    "historicalRetail": "1.99",
                    "historicalKeyshops": "1.50",
                    "currency": "EUR",
                },
            },
            "999999": None,
            "420": {
                "title": "Half-Life 2: Episode Two",
                "url": "https://gg.deals/game/half-life-2-episode-two/",
                "prices": {
                    "currentRetail": None,
                    "currentKeyshops": "3.00",
                    "historicalRetail": None,
                    "historicalKeyshops": None,
                    "currency": "EUR",
                },
            },
        },
    }


async def test_get_prices_sends_the_ids_and_the_key_and_parses_the_answer(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "api.gg.deals"
        assert request.url.path == "/v1/prices/by-steam-app-id/"
        assert request.url.params["ids"] == "220,999999,420"
        assert request.url.params["key"] == _KEY
        return httpx.Response(200, json=_body())

    _mock_client(handler, monkeypatch)

    prices = await get_prices_by_steam_app_ids([220, 999999, 420], _KEY)

    half_life = prices[220]
    assert half_life is not None
    assert half_life.url == "https://gg.deals/game/half-life-2/"
    prices_of = half_life.prices
    assert prices_of.currency == "EUR"
    assert (prices_of.current_retail, prices_of.current_keyshops) == ("9.99", "4.50")
    assert (prices_of.historical_retail, prices_of.historical_keyshops) == ("1.99", "1.50")


async def test_an_unknown_game_is_none_and_missing_prices_stay_none(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _mock_client(lambda request: httpx.Response(200, json=_body()), monkeypatch)

    prices = await get_prices_by_steam_app_ids([220, 999999, 420], _KEY)

    assert prices[999999] is None
    episode = prices[420]
    assert episode is not None
    assert episode.prices.current_retail is None
    assert episode.prices.current_keyshops == "3.00"


async def test_a_game_missing_from_the_answer_is_none(monkeypatch: pytest.MonkeyPatch) -> None:
    _mock_client(
        lambda request: httpx.Response(200, json={"success": True, "data": {}}), monkeypatch
    )

    assert await get_prices_by_steam_app_ids([220], _KEY) == {220: None}


async def test_no_ids_means_no_request(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("no request expected")

    _mock_client(handler, monkeypatch)

    assert await get_prices_by_steam_app_ids([], _KEY) == {}


@pytest.mark.parametrize("status", [401, 403, 429, 500])
async def test_an_error_status_raises_without_the_key_in_the_message(
    status: int, monkeypatch: pytest.MonkeyPatch
) -> None:
    _mock_client(lambda request: httpx.Response(status), monkeypatch)

    with pytest.raises(httpx.HTTPStatusError) as raised:
        await get_prices_by_steam_app_ids([220], _KEY)

    assert raised.value.response.status_code == status
    assert _KEY not in str(raised.value)


async def test_an_unsuccessful_or_unreadable_answer_raises(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _mock_client(
        lambda request: httpx.Response(200, json={"success": False, "data": {}}), monkeypatch
    )
    with pytest.raises(httpx.DecodingError):
        await get_prices_by_steam_app_ids([220], _KEY)

    _mock_client(lambda request: httpx.Response(200, content=b"<html>"), monkeypatch)
    with pytest.raises(httpx.DecodingError):
        await get_prices_by_steam_app_ids([220], _KEY)


async def test_a_transport_error_does_not_leak_the_key_into_the_log(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom", request=request)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.ConnectError):
        await get_prices_by_steam_app_ids([220], _KEY)

    captured = capsys.readouterr()
    assert _KEY not in captured.out + captured.err


def test_the_http_library_does_not_log_request_urls() -> None:
    assert logging.getLogger("httpx").getEffectiveLevel() >= logging.WARNING

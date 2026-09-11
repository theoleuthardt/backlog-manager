from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.key_shops.shopify import search_shopify_store


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


def _suggest_response(products: list[dict[str, object]]) -> httpx.Response:
    return httpx.Response(200, json={"resources": {"results": {"products": products}}})


async def test_search_shopify_store_returns_offers(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/search/suggest.json"
        assert request.url.params["q"] == "hades ii"
        assert request.url.params["resources[type]"] == "product"
        return _suggest_response(
            [
                {
                    "title": "Hades II PC Steam Account",
                    "price": "10.15",
                    "handle": "hades-ii-pc-steam-account",
                    "compare_at_price_max": "0.00",
                }
            ]
        )

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "hades ii")

    assert len(offers) == 1
    offer = offers[0]
    assert offer.shop == "RoyalCDKeys"
    assert offer.title == "Hades II PC Steam Account"
    assert offer.price == 10.15
    assert offer.currency == "EUR"
    assert offer.url == "https://royalcdkeys.com/products/hades-ii-pc-steam-account"
    assert offer.discount_pct is None


async def test_search_shopify_store_rejects_sequel_for_base_game_search(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A "hades" search must not match "Hades II ..." - that's a different
    game. See _matches_search_title."""

    def handler(request: httpx.Request) -> httpx.Response:
        return _suggest_response(
            [
                {
                    "title": "Hades II PC Steam Account",
                    "price": "10.15",
                    "handle": "hades-ii-pc-steam-account",
                    "compare_at_price_max": "0.00",
                }
            ]
        )

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "hades")

    assert offers == []


async def test_search_shopify_store_matches_core_title_number(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Numbers with 3+ digits are part of the core title, not sequel
    markers - "cyberpunk" matches "Cyberpunk 2077 GOG CD Key"."""

    def handler(request: httpx.Request) -> httpx.Response:
        return _suggest_response(
            [
                {
                    "title": "Cyberpunk 2077 GOG CD Key",
                    "price": "20.00",
                    "handle": "cyberpunk-2077-gog-cd-key",
                }
            ]
        )

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "cyberpunk")

    assert len(offers) == 1
    assert offers[0].price == 20.00


async def test_search_shopify_store_skips_product_with_invalid_price(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """One malformed/non-finite price must only discard that product, not
    the shop's valid ones - external Shopify responses are validated at
    this boundary."""

    def handler(request: httpx.Request) -> httpx.Response:
        return _suggest_response(
            [
                {
                    "title": "Hades Steam CD Key",
                    "price": "not-a-number",
                    "handle": "hades-broken",
                },
                {
                    "title": "Hades EU Steam CD Key",
                    "price": "NaN",
                    "handle": "hades-nan",
                },
                {
                    "title": "Hades PC Steam CD Key",
                    "price": "25.96",
                    "handle": "hades-cd-key",
                },
            ]
        )

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "hades")

    assert len(offers) == 1
    assert offers[0].price == 25.96


async def test_search_shopify_store_computes_discount_pct(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return _suggest_response(
            [
                {
                    "title": "Cyberpunk 2077 GOG CD Key",
                    "price": "20.00",
                    "handle": "cyberpunk-2077-gog-cd-key",
                    "compare_at_price_max": "40.00",
                }
            ]
        )

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "cyberpunk")

    assert offers[0].discount_pct == 50


async def test_search_shopify_store_returns_empty_list_on_no_match(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return _suggest_response([])

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "nonexistent")

    assert offers == []


async def test_search_shopify_store_filters_out_unrelated_titles(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Shopify's suggest endpoint is a fuzzy full-text search - it also
    matches unrelated products via tags/body text, e.g. "Assassin's Creed"
    listings for a "Hitman" search - see search_shopify_store's
    docstring."""

    def handler(request: httpx.Request) -> httpx.Response:
        return _suggest_response(
            [
                {
                    "title": "HITMAN World of Assassination Steam Account",
                    "price": "11.39",
                    "handle": "hitman-woa-steam-account",
                },
                {
                    "title": "Assassin's Creed Valhalla PC Steam CD Key",
                    "price": "8.73",
                    "handle": "ac-valhalla-cd-key",
                },
            ]
        )

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "hitman")

    assert len(offers) == 1
    assert offers[0].title == "HITMAN World of Assassination Steam Account"


async def test_search_shopify_store_collapses_to_cheapest_matching_offer(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A single game has multiple real listings at one shop (CD Key, EU CD
    Key, Steam Account, ...) - the caller wants the best price at this
    shop, not every SKU."""

    def handler(request: httpx.Request) -> httpx.Response:
        return _suggest_response(
            [
                {
                    "title": "HITMAN World of Assassination PC Steam CD Key",
                    "price": "25.96",
                    "handle": "hitman-woa-cd-key",
                },
                {
                    "title": "HITMAN World of Assassination Steam Account",
                    "price": "11.39",
                    "handle": "hitman-woa-steam-account",
                },
                {
                    "title": "HITMAN World of Assassination EU PC Steam CD Key",
                    "price": "25.61",
                    "handle": "hitman-woa-eu-cd-key",
                },
            ]
        )

    _mock_client(handler, monkeypatch)

    offers = await search_shopify_store(
        "RoyalCDKeys", "https://royalcdkeys.com", "hitman world of assassination"
    )

    assert len(offers) == 1
    assert offers[0].price == 11.39
    assert offers[0].title == "HITMAN World of Assassination Steam Account"


async def test_search_shopify_store_raises_on_http_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await search_shopify_store("RoyalCDKeys", "https://royalcdkeys.com", "hades")

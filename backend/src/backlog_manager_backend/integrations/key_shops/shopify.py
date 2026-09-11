from datetime import UTC, datetime

import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import KeyShopOffer

logger = structlog.get_logger()

_SUGGEST_PATH = "/search/suggest.json"


class _ShopifySuggestProduct(msgspec.Struct):
    title: str
    price: str
    handle: str
    compare_at_price_max: str = "0.00"


class _ShopifySuggestResults(msgspec.Struct):
    products: list[_ShopifySuggestProduct] = []


class _ShopifySuggestResources(msgspec.Struct):
    results: _ShopifySuggestResults


class _ShopifySuggestResponse(msgspec.Struct):
    resources: _ShopifySuggestResources


def _discount_pct(price: float, compare_at_price_max: float) -> int | None:
    """None (not 0) when the shop reports no compare-at price at all -
    both RoyalCDKeys and PremiumCDKeys send "0.00" for products with no
    listed discount, which isn't a real 100% discount."""
    if compare_at_price_max <= price:
        return None
    return round((1 - price / compare_at_price_max) * 100)


async def search_shopify_store(shop_name: str, base_url: str, title: str) -> list[KeyShopOffer]:
    """Queries a Shopify storefront's public predictive-search endpoint -
    see docs/KEY_SHOP_SCRAPING.md for why this (rather than scraping
    product pages) is the legal, robots.txt-compliant way to search these
    two shops. Shared by every Shopify-based adapter since the response
    shape is identical across stores; only base_url/shop_name differ."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(10.0)) as client:
            response = await client.get(
                f"{base_url}{_SUGGEST_PATH}",
                params={"q": title, "resources[type]": "product", "resources[limit]": "10"},
            )
        response.raise_for_status()
    except httpx.HTTPError as error:
        logger.error(f"{shop_name} search error", error=str(error))
        raise

    try:
        decoded = msgspec.json.decode(response.content, type=_ShopifySuggestResponse)
    except msgspec.DecodeError as error:
        logger.error(f"{shop_name} search decode error", error=str(error))
        raise httpx.DecodingError(f"{shop_name} returned an invalid response") from error

    now = datetime.now(UTC).replace(tzinfo=None)
    return [
        KeyShopOffer(
            shop=shop_name,
            title=product.title,
            price=float(product.price),
            currency="EUR",
            url=f"{base_url}/products/{product.handle}",
            fetched_at=now,
            discount_pct=_discount_pct(float(product.price), float(product.compare_at_price_max)),
        )
        for product in decoded.resources.results.products
    ]

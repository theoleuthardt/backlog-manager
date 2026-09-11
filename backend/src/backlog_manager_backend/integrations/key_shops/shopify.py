import math
import re
from datetime import UTC, datetime

import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import KeyShopOffer

logger = structlog.get_logger()

_SUGGEST_PATH = "/search/suggest.json"

_SEQUEL_TOKENS = frozenset(
    {"ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii", "xiii", "xiv", "xv"}
)


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


def _words(title: str) -> list[str]:
    return re.findall(r"[a-z0-9']+", title.lower())


def _matches_search_title(search_title: str, product_title: str) -> bool:
    """Whole-word prefix match that rejects immediate sequel markers:
    "hades" matches "Hades Steam CD Key" but not "Hades II PC Steam
    Account" (a different game), while "hades ii" still matches the
    latter. Roman numerals and 1-2 digit arabic numbers count as sequel
    markers, longer numbers don't ("Cyberpunk 2077" for a "cyberpunk"
    search is the same game, not a sequel). Everything after the first
    continuation word is edition/platform decoration ("EU PC Steam CD
    Key") and allowed."""
    search_words = _words(search_title)
    product_words = _words(product_title)
    if product_words[: len(search_words)] != search_words:
        return False
    continuation = product_words[len(search_words) :]
    if not continuation:
        return True
    first = continuation[0]
    return first not in _SEQUEL_TOKENS and not re.fullmatch(r"\d{1,2}", first)


async def search_shopify_store(shop_name: str, base_url: str, title: str) -> list[KeyShopOffer]:
    """Queries a Shopify storefront's public predictive-search endpoint -
    see docs/KEY_SHOP_SCRAPING.md for why this (rather than scraping
    product pages) is the legal, robots.txt-compliant way to search these
    two shops. Shared by every Shopify-based adapter since the response
    shape is identical across stores; only base_url/shop_name differ.

    Shopify's suggest endpoint is a fuzzy full-text search, not an exact
    title match - searching "Hitman World of Assassination" also returns
    unrelated Assassin's Creed listings (Shopify matches against
    tags/body text too, not just the title) alongside every real edition
    of the requested game (Steam CD Key, EU CD Key, Steam Account -
    genuinely different listings, not duplicates). Filtering to product
    titles that extend the searched title (see _matches_search_title)
    removes the former and the sequels; collapsing to the single cheapest
    match removes the latter, since a caller wants "the best price at
    this shop", not every SKU. Products with malformed, non-finite or
    non-positive prices are skipped individually so one bad listing
    can't discard the shop's valid ones."""
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
    offers: list[KeyShopOffer] = []
    for product in decoded.resources.results.products:
        if not _matches_search_title(title, product.title):
            continue
        try:
            price = float(product.price)
            compare_at_price_max = float(product.compare_at_price_max)
        except ValueError:
            logger.warning(f"{shop_name} product has a malformed price", product=product.title)
            continue
        if not math.isfinite(price) or price <= 0 or not math.isfinite(compare_at_price_max):
            logger.warning(f"{shop_name} product has an invalid price", product=product.title)
            continue
        offers.append(
            KeyShopOffer(
                shop=shop_name,
                title=product.title,
                price=price,
                currency="EUR",
                url=f"{base_url}/products/{product.handle}",
                fetched_at=now,
                discount_pct=_discount_pct(price, compare_at_price_max),
            )
        )
    if not offers:
        return []
    return [min(offers, key=lambda offer: offer.price)]
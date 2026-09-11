import asyncio

import structlog

from backlog_manager_backend.integrations.key_shops import premiumcdkeys, royalcdkeys
from backlog_manager_backend.integrations.types import KeyShopOffer

logger = structlog.get_logger()

_ADAPTERS = (royalcdkeys, premiumcdkeys)


async def search_key_shops(title: str) -> list[KeyShopOffer]:
    """Queries every adapter in _ADAPTERS concurrently and returns the
    combined offers. A failing/timing-out adapter is logged and excluded
    rather than failing the whole search, so one broken shop can't block
    the others - same asyncio.gather(..., return_exceptions=True) pattern
    the issue's Technical Approach section asks for. Two shops today (see
    docs/KEY_SHOP_SCRAPING.md for why the issue's originally named
    Phase-1 shops aren't scrapable without violating robots.txt or
    bypassing bot protection) - adding a shop means adding one adapter
    module under integrations/key_shops/ and listing it in _ADAPTERS, no
    other changes."""
    results = await asyncio.gather(
        *(adapter.search(title) for adapter in _ADAPTERS), return_exceptions=True
    )

    offers: list[KeyShopOffer] = []
    for adapter, result in zip(_ADAPTERS, results, strict=True):
        if isinstance(result, BaseException):
            logger.error(
                "Key shop search failed",
                shop=adapter.SHOP_NAME,
                error_type=type(result).__name__,
            )
            continue
        offers.extend(result)
    return offers

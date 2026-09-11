from backlog_manager_backend.integrations.key_shops.shopify import search_shopify_store
from backlog_manager_backend.integrations.types import KeyShopOffer

SHOP_NAME = "PremiumCDKeys"
_BASE_URL = "https://www.premiumcdkeys.com"


async def search(title: str) -> list[KeyShopOffer]:
    return await search_shopify_store(SHOP_NAME, _BASE_URL, title)

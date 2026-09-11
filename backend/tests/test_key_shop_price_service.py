from datetime import UTC, datetime

import pytest

from backlog_manager_backend.integrations.key_shops import premiumcdkeys, royalcdkeys
from backlog_manager_backend.integrations.types import KeyShopOffer
from backlog_manager_backend.services import key_shop_price_service

_NOW = datetime(2026, 1, 1, tzinfo=UTC).replace(tzinfo=None)


async def test_search_key_shops_combines_all_adapter_results(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def fake_royalcdkeys_search(title: str) -> list[KeyShopOffer]:
        return [
            KeyShopOffer(
                shop="RoyalCDKeys",
                title=title,
                price=10.0,
                currency="EUR",
                url="a",
                fetched_at=_NOW,
            )
        ]

    async def fake_premiumcdkeys_search(title: str) -> list[KeyShopOffer]:
        return [
            KeyShopOffer(
                shop="PremiumCDKeys",
                title=title,
                price=12.0,
                currency="EUR",
                url="b",
                fetched_at=_NOW,
            )
        ]

    monkeypatch.setattr(royalcdkeys, "search", fake_royalcdkeys_search)
    monkeypatch.setattr(premiumcdkeys, "search", fake_premiumcdkeys_search)

    offers = await key_shop_price_service.search_key_shops("hades")

    assert {offer.shop for offer in offers} == {"RoyalCDKeys", "PremiumCDKeys"}


async def test_search_key_shops_excludes_a_failing_adapter(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def failing_search(title: str) -> list[KeyShopOffer]:
        raise RuntimeError("boom")

    async def working_search(title: str) -> list[KeyShopOffer]:
        return [
            KeyShopOffer(
                shop="PremiumCDKeys",
                title=title,
                price=12.0,
                currency="EUR",
                url="b",
                fetched_at=_NOW,
            )
        ]

    monkeypatch.setattr(royalcdkeys, "search", failing_search)
    monkeypatch.setattr(premiumcdkeys, "search", working_search)

    offers = await key_shop_price_service.search_key_shops("hades")

    assert len(offers) == 1
    assert offers[0].shop == "PremiumCDKeys"

from datetime import UTC, datetime

import pytest
from litestar.testing import TestClient

from backlog_manager_backend.integrations.types import KeyShopOffer

_NOW = datetime(2026, 1, 1, tzinfo=UTC).replace(tzinfo=None)


async def test_get_key_shop_prices_requires_auth(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/key-shop-prices?title=hades")

    assert response.status_code == 401


async def test_get_key_shop_prices_rejects_empty_title(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "keyshoproute-empty@example.com")
        response = client.get("/api/games/key-shop-prices?title=", headers=headers)

    assert response.status_code == 400


async def test_get_key_shop_prices_returns_combined_offers(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import games as games_routes

    async def fake_search_key_shops(title: str) -> list[KeyShopOffer]:
        assert title == "hades"
        return [
            KeyShopOffer(
                shop="RoyalCDKeys",
                title="Hades II PC Steam Account",
                price=10.15,
                currency="EUR",
                url="https://royalcdkeys.com/products/hades-ii-pc-steam-account",
                fetched_at=_NOW,
            )
        ]

    monkeypatch.setattr(
        games_routes.key_shop_price_service, "search_key_shops", fake_search_key_shops
    )

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "keyshoproute@example.com")
        response = client.get("/api/games/key-shop-prices?title=hades", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["shop"] == "RoyalCDKeys"
    assert body[0]["price"] == 10.15

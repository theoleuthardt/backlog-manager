from datetime import UTC, datetime

import httpx
import pytest
from litestar.testing import TestClient

from backlog_manager_backend.schemas.game_price import GamePrice, GamePriceDeal


async def test_get_game_price_requires_auth(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/220/price")

    assert response.status_code == 401


async def test_get_game_price_returns_price_info(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import games as games_routes

    async def fake_get_price_info(session: object, steam_app_id: int) -> GamePrice:
        assert steam_app_id == 220
        return GamePrice(
            steam_app_id=220,
            deals=[
                GamePriceDeal(
                    store="Steam",
                    icon="https://example.com/icon.png",
                    price=9.99,
                    retail_price=19.99,
                    url="https://example.com/deal",
                )
            ],
            on_sale=True,
            checked_at=datetime(2026, 1, 1, 12, 0, tzinfo=UTC).replace(tzinfo=None),
        )

    monkeypatch.setattr(games_routes.price_service, "get_price_info", fake_get_price_info)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "priceroute@example.com")
        response = client.get("/api/games/220/price", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["steam_app_id"] == 220
    assert body["on_sale"] is True
    assert body["deals"] == [
        {
            "store": "Steam",
            "icon": "https://example.com/icon.png",
            "price": 9.99,
            "retail_price": 19.99,
            "url": "https://example.com/deal",
        }
    ]


async def test_get_game_price_returns_503_when_cheapshark_unreachable(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import games as games_routes

    async def fake_get_price_info(session: object, steam_app_id: int) -> GamePrice:
        raise httpx.ConnectTimeout("timed out")

    monkeypatch.setattr(games_routes.price_service, "get_price_info", fake_get_price_info)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "priceroute503@example.com")
        response = client.get("/api/games/220/price", headers=headers)

    assert response.status_code == 503

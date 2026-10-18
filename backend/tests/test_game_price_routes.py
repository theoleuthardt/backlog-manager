from datetime import UTC, datetime
from decimal import Decimal

import httpx
import pytest
from litestar.testing import TestClient

from backlog_manager_backend.schemas.game_price import GamePrice


async def test_get_game_price_requires_auth(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.get("/api/games/220/price")

    assert response.status_code == 401


async def test_get_game_price_returns_the_prices(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.routes import games as games_routes

    asked: list[tuple[int, str | None]] = []

    async def fake_get_price_info(
        session: object, steam_app_id: int, api_key: str | None
    ) -> GamePrice:
        asked.append((steam_app_id, api_key))
        return GamePrice(
            steam_app_id=220,
            checked_at=datetime(2026, 1, 1, 12, 0, tzinfo=UTC).replace(tzinfo=None),
            currency="EUR",
            current_retail=Decimal("9.99"),
            current_keyshops=Decimal("4.50"),
            historical_retail=Decimal("1.99"),
            historical_keyshops=None,
            url="https://gg.deals/game/half-life-2/",
        )

    monkeypatch.setattr(settings, "ggdeals_api_key", "server-key")
    monkeypatch.setattr(games_routes.price_service, "get_price_info", fake_get_price_info)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "priceroute@example.com")
        response = client.get("/api/games/220/price", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["steam_app_id"] == 220
    assert body["currency"] == "EUR"
    assert body["current_retail"] == "9.99"
    assert body["current_keyshops"] == "4.50"
    assert body["historical_retail"] == "1.99"
    assert body["historical_keyshops"] is None
    assert body["url"] == "https://gg.deals/game/half-life-2/"
    assert asked == [(220, "server-key")]


async def test_get_game_price_uses_the_users_own_key_first(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str, create_and_login
) -> None:
    from cryptography.fernet import Fernet

    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.routes import games as games_routes

    asked: list[str | None] = []

    async def fake_get_price_info(
        session: object, steam_app_id: int, api_key: str | None
    ) -> GamePrice:
        asked.append(api_key)
        return GamePrice(
            steam_app_id=steam_app_id,
            checked_at=datetime(2026, 1, 1, tzinfo=UTC).replace(tzinfo=None),
        )

    monkeypatch.setattr(settings, "steam_api_key_encryption_key", Fernet.generate_key().decode())
    monkeypatch.setattr(settings, "ggdeals_api_key", "server-key")
    monkeypatch.setattr(games_routes.price_service, "get_price_info", fake_get_price_info)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "priceownkey@example.com")
        client.put("/api/user/me", headers=headers, json={"ggdeals_api_key": "own-key"})
        client.get("/api/games/220/price", headers=headers)

    assert asked == ["own-key"]


async def test_get_game_price_is_503_when_gg_deals_is_unreachable(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import games as games_routes

    async def fake_get_price_info(
        session: object, steam_app_id: int, api_key: str | None
    ) -> GamePrice:
        raise httpx.ConnectTimeout("timed out")

    monkeypatch.setattr(games_routes.price_service, "get_price_info", fake_get_price_info)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "priceroute503@example.com")
        response = client.get("/api/games/220/price", headers=headers)

    assert response.status_code == 503


async def test_get_game_price_is_503_without_any_key(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "ggdeals_api_key", None)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "pricenokey@example.com")
        response = client.get("/api/games/220/price", headers=headers)

    assert response.status_code == 503
    assert "not configured" in response.text

import pytest
from litestar.testing import TestClient


async def test_check_prices_requires_secret_header(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import prices as prices_routes

    monkeypatch.setattr(prices_routes.settings, "price_check_cron_secret", "shh")

    with TestClient(app=create_app()) as client:
        response = client.post("/api/prices/check")

    assert response.status_code == 401


async def test_check_prices_rejects_wrong_secret(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import prices as prices_routes

    monkeypatch.setattr(prices_routes.settings, "price_check_cron_secret", "shh")

    with TestClient(app=create_app()) as client:
        response = client.post("/api/prices/check", headers={"X-Cron-Secret": "wrong"})

    assert response.status_code == 401


async def test_check_prices_rejects_when_secret_not_configured(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import prices as prices_routes

    monkeypatch.setattr(prices_routes.settings, "price_check_cron_secret", None)

    with TestClient(app=create_app()) as client:
        response = client.post("/api/prices/check", headers={"X-Cron-Secret": "anything"})

    assert response.status_code == 401


async def test_check_prices_runs_sweep_with_valid_secret(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import prices as prices_routes

    monkeypatch.setattr(prices_routes.settings, "price_check_cron_secret", "shh")

    async def fake_check_prices_and_alert(session: object) -> int:
        return 3

    monkeypatch.setattr(
        prices_routes.price_service, "check_prices_and_alert", fake_check_prices_and_alert
    )

    with TestClient(app=create_app()) as client:
        response = client.post("/api/prices/check", headers={"X-Cron-Secret": "shh"})

    assert response.status_code == 200
    assert response.json() == {"alerts_sent": 3}

from collections.abc import Awaitable, Callable

import pytest
from litestar.testing import TestClient

from backlog_manager_backend.schemas.steam_wishlist_sync import (
    SteamWishlistChange,
    SteamWishlistSyncReport,
)


async def test_auto_sync_requires_the_cron_secret(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import prices as prices_routes

    monkeypatch.setattr(prices_routes.settings, "price_check_cron_secret", "shh")

    with TestClient(app=create_app()) as client:
        missing = client.post("/api/steam/wishlist/auto-sync")
        wrong = client.post("/api/steam/wishlist/auto-sync", headers={"X-Cron-Secret": "no"})

    assert missing.status_code == 401
    assert wrong.status_code == 401


async def test_auto_sync_runs_for_opted_in_users_with_the_secret(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import prices as prices_routes
    from backlog_manager_backend.routes import steam_wishlist_sync as sync_routes
    from backlog_manager_backend.services import steam_wishlist_sync_service

    monkeypatch.setattr(prices_routes.settings, "price_check_cron_secret", "shh")

    async def fake_sync_all(session: object, credentials_for: object) -> object:
        return steam_wishlist_sync_service.SyncSummary(users=2, added=3, removed=1)

    monkeypatch.setattr(sync_routes.steam_wishlist_sync_service, "sync_all", fake_sync_all)

    with TestClient(app=create_app()) as client:
        response = client.post("/api/steam/wishlist/auto-sync", headers={"X-Cron-Secret": "shh"})

    assert response.status_code == 200
    assert response.json() == {"users": 2, "added": 3, "removed": 1, "failed": 0}


async def test_sync_report_is_empty_until_the_sync_changed_something(
    create_and_login: Callable[..., Awaitable[dict[str, str]]], postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "emptyreport@example.com")
        response = client.get("/api/user/steam/wishlist/sync-report", headers=headers)

    assert response.status_code == 200
    assert response.json() == {"since": None, "added": [], "removed": []}


async def test_sync_report_can_be_read_and_dismissed(
    create_and_login: Callable[..., Awaitable[dict[str, str]]], postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.db import async_session
    from backlog_manager_backend.repositories import user_repo
    from backlog_manager_backend.schemas.user import UpdateUserParams

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "report@example.com")
        me = client.get("/api/user/me", headers=headers).json()
        async with async_session() as session:
            await user_repo.update_user(
                session,
                UpdateUserParams(
                    user_id=me["id"],
                    steam_wishlist_sync_report=SteamWishlistSyncReport(
                        added=[SteamWishlistChange(steam_app_id=620, title="Portal 2")],
                        removed=[SteamWishlistChange(steam_app_id=10, title="Counter-Strike")],
                    ),
                ),
            )

        report = client.get("/api/user/steam/wishlist/sync-report", headers=headers).json()
        dismissed = client.delete("/api/user/steam/wishlist/sync-report", headers=headers)
        after = client.get("/api/user/steam/wishlist/sync-report", headers=headers).json()

    assert [c["title"] for c in report["added"]] == ["Portal 2"]
    assert [c["title"] for c in report["removed"]] == ["Counter-Strike"]
    assert dismissed.status_code == 200
    assert after["added"] == [] and after["removed"] == []


async def test_the_auto_sync_setting_is_saved_on_the_account(
    create_and_login: Callable[..., Awaitable[dict[str, str]]], postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "autosyncflag@example.com")
        before = client.get("/api/user/me", headers=headers).json()
        client.put("/api/user/me", headers=headers, json={"steam_wishlist_auto_sync": True})
        after = client.get("/api/user/me", headers=headers).json()

    assert before["steam_wishlist_auto_sync"] is False
    assert after["steam_wishlist_auto_sync"] is True

from litestar.testing import TestClient


def _create_entry(client: TestClient, headers: dict[str, str], title: str) -> dict:
    response = client.post(
        "/api/backlog/entries",
        headers=headers,
        json={
            "title": title,
            "genre": ["RPG"],
            "platform": ["PC"],
            "status": "Not Started",
            "owned": True,
            "interest": 7,
        },
    )
    assert response.status_code == 201
    return response.json()


def _titles(client: TestClient, headers: dict[str, str]) -> list[str]:
    response = client.get("/api/backlog/entries", headers=headers)
    assert response.status_code == 200
    return sorted(entry["title"] for entry in response.json())


async def test_backup_routes_require_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        statuses = [
            client.get("/api/backups").status_code,
            client.post("/api/backups").status_code,
            client.get("/api/backups/1/download").status_code,
            client.post("/api/backups/1/restore").status_code,
            client.delete("/api/backups/1").status_code,
        ]

    assert statuses == [401] * 5


async def test_create_and_list_backups(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "backuplist@example.com")
        _create_entry(client, headers, "Hades")
        created = client.post("/api/backups", headers=headers)
        listed = client.get("/api/backups", headers=headers)

    assert created.status_code == 201
    assert created.json()["kind"] == "manual"
    assert created.json()["entry_count"] == 1
    assert listed.json() == [created.json()]


async def test_download_returns_the_snapshot_as_a_json_attachment(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "backupdownload@example.com")
        _create_entry(client, headers, "Hades")
        backup = client.post("/api/backups", headers=headers).json()
        response = client.get(f"/api/backups/{backup['id']}/download", headers=headers)

    assert response.status_code == 200
    assert "attachment" in response.headers["content-disposition"]
    assert response.json()["entries"][0]["title"] == "Hades"


async def test_restore_reverts_the_backlog_to_the_snapshot(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "backuprestore@example.com")
        _create_entry(client, headers, "Hades")
        backup = client.post("/api/backups", headers=headers).json()
        _create_entry(client, headers, "Added later")

        restored = client.post(f"/api/backups/{backup['id']}/restore", headers=headers)
        titles = _titles(client, headers)

    assert restored.status_code == 200
    assert restored.json()["entry_count"] == 1
    assert restored.json()["safety_backup_id"] is not None
    assert titles == ["Hades"]


async def test_deleting_all_entries_takes_a_safety_backup_first(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "backupbulkdelete@example.com")
        _create_entry(client, headers, "Hades")
        _create_entry(client, headers, "Celeste")

        deleted = client.delete("/api/backlog/entries", headers=headers)
        backups = client.get("/api/backups", headers=headers).json()
        restored = client.post(f"/api/backups/{backups[0]['id']}/restore", headers=headers)
        titles = _titles(client, headers)

    assert deleted.json() == 2
    assert [backup["kind"] for backup in backups] == ["pre-delete"]
    assert restored.status_code == 200
    assert titles == ["Celeste", "Hades"]


async def test_delete_backup_removes_it_from_the_list(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "backupdelete@example.com")
        backup = client.post("/api/backups", headers=headers).json()
        deleted = client.delete(f"/api/backups/{backup['id']}", headers=headers)
        listed = client.get("/api/backups", headers=headers)

    assert deleted.status_code == 204
    assert listed.json() == []


async def test_another_users_backup_is_not_accessible(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner_headers = await create_and_login(client, "backupowner2@example.com")
        intruder_headers = await create_and_login(client, "backupintruder2@example.com")
        _create_entry(client, owner_headers, "Hades")
        backup = client.post("/api/backups", headers=owner_headers).json()
        backup_id = backup["id"]

        statuses = [
            client.get(f"/api/backups/{backup_id}/download", headers=intruder_headers).status_code,
            client.post(f"/api/backups/{backup_id}/restore", headers=intruder_headers).status_code,
            client.delete(f"/api/backups/{backup_id}", headers=intruder_headers).status_code,
        ]
        intruder_list = client.get("/api/backups", headers=intruder_headers).json()

    assert statuses == [404, 404, 404]
    assert intruder_list == []


async def test_restoring_an_unknown_backup_returns_404(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "backupunknown@example.com")
        response = client.post("/api/backups/999999999/restore", headers=headers)

    assert response.status_code == 404


async def test_scheduler_starts_and_stops_with_the_app_when_enabled(
    postgres_url: str, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "backup_scheduler_enabled", True)
    app = create_app()

    with TestClient(app=app):
        task = app.state.backup_scheduler_task
        assert not task.done()

    assert task.done()


async def test_scheduler_is_not_started_when_disabled(postgres_url: str, monkeypatch) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "backup_scheduler_enabled", False)
    app = create_app()

    with TestClient(app=app):
        assert not hasattr(app.state, "backup_scheduler_task")

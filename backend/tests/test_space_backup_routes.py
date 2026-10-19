from litestar.testing import TestClient


def _make_space(client: TestClient, owner: dict, guest: dict, guest_name: str) -> int:
    client.post("/api/space/invitations", headers=owner, json={"username": guest_name})
    return client.post("/api/space/invitations/accept", headers=guest).json()["space_id"]


def _add_entry(client: TestClient, headers: dict, space_id: int, title: str) -> int:
    response = client.post(
        f"/api/backlog/entries?space_id={space_id}",
        headers=headers,
        json={
            "title": title,
            "genre": ["Co-op"],
            "platform": ["PC"],
            "status": "Not Started",
            "owned": True,
            "interest": 6,
            "steam_app_id": 548430,
            "review": "My own review",
            "review_stars": 4,
        },
    )
    assert response.status_code == 201
    return response.json()["id"]


def _titles(client: TestClient, headers: dict, space_id: int) -> list[str]:
    response = client.get(f"/api/backlog/entries?space_id={space_id}", headers=headers)
    assert response.status_code == 200
    return sorted(entry["title"] for entry in response.json())


async def test_space_backup_routes_require_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        statuses = [
            client.get("/api/space/backups").status_code,
            client.post("/api/space/backups").status_code,
            client.get("/api/space/backups/1/download").status_code,
            client.get("/api/space/export").status_code,
            client.post("/api/space/backups/1/restore").status_code,
            client.post("/api/space/restore-request/approve").status_code,
            client.delete("/api/space/restore-request").status_code,
        ]

    assert statuses == [401] * 7


async def test_a_user_without_a_space_gets_a_404(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "spbkalone@example.com")
        statuses = [
            client.get("/api/space/backups", headers=headers).status_code,
            client.post("/api/space/backups", headers=headers).status_code,
            client.get("/api/space/export", headers=headers).status_code,
            client.post("/api/space/restore-request/approve", headers=headers).status_code,
        ]

    assert statuses == [404] * 4


async def test_restore_needs_both_members(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spbkowner@example.com")
        guest = await create_and_login(client, "spbkguest@example.com")
        space_id = _make_space(client, owner, guest, "spbkguest")
        _add_entry(client, owner, space_id, "Deep Rock Galactic")
        backup = client.post("/api/space/backups", headers=guest)
        client.delete(f"/api/backlog/entries?space_id={space_id}", headers=owner)

        asked = client.post(f"/api/space/backups/{backup.json()['id']}/restore", headers=owner)
        before = _titles(client, owner, space_id)
        own_approval = client.post("/api/space/restore-request/approve", headers=owner)
        listed = client.get("/api/space/backups", headers=guest).json()
        approved = client.post("/api/space/restore-request/approve", headers=guest)
        after = _titles(client, owner, space_id)
        none_left = client.get("/api/space/backups", headers=owner).json()

    assert backup.status_code == 201
    assert backup.json()["created_by"] == "spbkguest"
    assert asked.status_code == 200
    assert asked.json()["restored"] is False
    assert asked.json()["request"]["requested_by_me"] is True
    assert before == []
    assert own_approval.status_code == 409
    assert listed["restore_request"]["requested_by"] == "spbkowner"
    assert listed["restore_request"]["requested_by_me"] is False
    assert approved.status_code == 200
    assert approved.json()["entry_count"] == 1
    assert after == ["Deep Rock Galactic"]
    assert none_left["restore_request"] is None


async def test_withdrawing_a_request_and_a_second_request(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spbkwdowner@example.com")
        guest = await create_and_login(client, "spbkwdguest@example.com")
        space_id = _make_space(client, owner, guest, "spbkwdguest")
        _add_entry(client, owner, space_id, "Valheim")
        backup_id = client.post("/api/space/backups", headers=owner).json()["id"]
        client.post(f"/api/space/backups/{backup_id}/restore", headers=owner)

        second = client.post(f"/api/space/backups/{backup_id}/restore", headers=guest)
        declined = client.delete("/api/space/restore-request", headers=guest)
        approve = client.post("/api/space/restore-request/approve", headers=guest)

    assert second.status_code == 409
    assert declined.status_code == 204
    assert approve.status_code == 404


async def test_downloads_only_hold_the_callers_own_member_data(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spbkdlowner@example.com")
        guest = await create_and_login(client, "spbkdlguest@example.com")
        space_id = _make_space(client, owner, guest, "spbkdlguest")
        entry_id = _add_entry(client, owner, space_id, "Deep Rock Galactic")
        client.put(
            f"/api/backlog/entries/{entry_id}?space_id={space_id}",
            headers=guest,
            json={"review": "Guest review"},
        )
        backup_id = client.post("/api/space/backups", headers=owner).json()["id"]

        backup_file = client.get(f"/api/space/backups/{backup_id}/download", headers=guest)
        export = client.get("/api/space/export", headers=owner)

    assert backup_file.status_code == 200
    assert "attachment" in backup_file.headers["content-disposition"]
    assert [row["review"] for row in backup_file.json()["member_data"]] == ["Guest review"]
    assert export.status_code == 200
    assert export.headers["content-disposition"].endswith('"space-backlog.json"')
    assert [row["review"] for row in export.json()["member_data"]] == ["My own review"]
    assert [entry["title"] for entry in export.json()["entries"]] == ["Deep Rock Galactic"]


async def test_emptying_the_space_takes_a_pre_delete_backup(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spbkpdowner@example.com")
        guest = await create_and_login(client, "spbkpdguest@example.com")
        space_id = _make_space(client, owner, guest, "spbkpdguest")
        _add_entry(client, owner, space_id, "Valheim")

        client.delete(f"/api/backlog/entries?space_id={space_id}", headers=owner)
        listed = client.get("/api/space/backups", headers=guest).json()["backups"]

    assert [(item["kind"], item["entry_count"]) for item in listed] == [("pre-delete", 1)]


async def test_rename_and_delete_over_http(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spbkrnowner@example.com")
        guest = await create_and_login(client, "spbkrnguest@example.com")
        _make_space(client, owner, guest, "spbkrnguest")
        backup_id = client.post("/api/space/backups", headers=owner).json()["id"]

        renamed = client.put(
            f"/api/space/backups/{backup_id}", headers=guest, json={"name": "Before the sale"}
        )
        too_long = client.put(
            f"/api/space/backups/{backup_id}", headers=guest, json={"name": "x" * 61}
        )
        deleted = client.delete(f"/api/space/backups/{backup_id}", headers=guest)
        missing = client.delete(f"/api/space/backups/{backup_id}", headers=guest)

    assert renamed.json()["name"] == "Before the sale"
    assert too_long.status_code == 400
    assert deleted.status_code == 204
    assert missing.status_code == 404

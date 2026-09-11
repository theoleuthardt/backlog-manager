from litestar.testing import TestClient


async def test_create_and_list_custom_statuses_round_trips(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "statusowner@example.com")

        create_response = client.post(
            "/api/backlog/statuses",
            headers=headers,
            json={"name": "Playing in Co-Op"},
        )
        assert create_response.status_code == 201
        created = create_response.json()
        assert created["name"] == "Playing in Co-Op"

        list_response = client.get("/api/backlog/statuses", headers=headers)

    assert list_response.status_code == 200
    assert [s["name"] for s in list_response.json()] == ["Playing in Co-Op"]


async def test_list_statuses_only_returns_own_statuses(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "statusa@example.com")
        headers_b = await create_and_login(client, "statusb@example.com")
        client.post("/api/backlog/statuses", headers=headers_a, json={"name": "Co-Op"})

        list_response = client.get("/api/backlog/statuses", headers=headers_b)

    assert list_response.status_code == 200
    assert list_response.json() == []


async def test_update_status_rejects_other_users_status(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "statusupd@example.com")
        headers_b = await create_and_login(client, "statusupdvictim@example.com")
        created = client.post(
            "/api/backlog/statuses", headers=headers_a, json={"name": "Co-Op"}
        ).json()

        update_response = client.put(
            f"/api/backlog/statuses/{created['id']}",
            headers=headers_b,
            json={"name": "Hacked"},
        )

    assert update_response.status_code == 404


async def test_update_and_delete_status(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "statusedit@example.com")
        created = client.post(
            "/api/backlog/statuses", headers=headers, json={"name": "Co-Op"}
        ).json()

        update_response = client.put(
            f"/api/backlog/statuses/{created['id']}",
            headers=headers,
            json={"name": "Playing in Co-Op"},
        )
        assert update_response.status_code == 200
        assert update_response.json()["name"] == "Playing in Co-Op"

        delete_response = client.delete(
            f"/api/backlog/statuses/{created['id']}", headers=headers
        )
        assert delete_response.status_code == 204

        list_response = client.get("/api/backlog/statuses", headers=headers)

    assert list_response.json() == []


async def test_create_status_validates_name(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "statusvalid@example.com")

        too_long = client.post(
            "/api/backlog/statuses",
            headers=headers,
            json={"name": "x" * 21},
        )
        assert too_long.status_code == 400

        empty = client.post(
            "/api/backlog/statuses",
            headers=headers,
            json={"name": "   "},
        )
        assert empty.status_code == 400


async def test_create_status_rejects_duplicate_default_status(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "statusdup@example.com")

        response = client.post(
            "/api/backlog/statuses",
            headers=headers,
            json={"name": "In Progress"},
        )

    assert response.status_code == 400


async def test_backlog_entry_accepts_custom_status(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "statusentry@example.com")

        create_response = client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "It Takes Two",
                "genre": ["Co-Op"],
                "platform": ["PC"],
                "status": "Playing in Co-Op",
                "owned": True,
                "interest": 8,
            },
        )
        assert create_response.status_code == 201
        assert create_response.json()["status"] == "Playing in Co-Op"
from litestar.testing import TestClient


def _register_and_login(client: TestClient, email: str) -> dict[str, str]:
    client.post(
        "/api/auth/register",
        json={"username": email.split("@")[0], "email": email, "password": "hunter2"},
    )
    login_response = client.post("/api/auth/login", json={"email": email, "password": "hunter2"})
    token = login_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_create_and_get_entry_round_trips(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers = _register_and_login(client, "entryowner@example.com")

        create_response = client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Celeste",
                "genre": ["Platformer", "Indie"],
                "platform": ["PC", "Switch"],
                "status": "Not Started",
                "owned": True,
                "interest": 8,
            },
        )
        assert create_response.status_code == 201
        created = create_response.json()
        assert created["title"] == "Celeste"
        assert created["genre"] == ["Platformer", "Indie"]
        assert created["platform"] == ["PC", "Switch"]

        get_response = client.get(f"/api/backlog/entries/{created['id']}", headers=headers)

    assert get_response.status_code == 200
    assert get_response.json() == created


def test_list_entries_only_returns_own_entries(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers_a = _register_and_login(client, "usera@example.com")
        headers_b = _register_and_login(client, "userb@example.com")

        client.post(
            "/api/backlog/entries",
            headers=headers_a,
            json={
                "title": "Owned by A",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )

        list_response = client.get("/api/backlog/entries", headers=headers_b)

    assert list_response.status_code == 200
    assert list_response.json() == []


def test_get_entry_by_id_rejects_other_users_entry(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers_a = _register_and_login(client, "ownera@example.com")
        headers_b = _register_and_login(client, "ownerb@example.com")

        create_response = client.post(
            "/api/backlog/entries",
            headers=headers_a,
            json={
                "title": "A's game",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )
        entry_id = create_response.json()["id"]

        response = client.get(f"/api/backlog/entries/{entry_id}", headers=headers_b)

    assert response.status_code == 404


def test_update_entry_rejects_other_users_entry(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers_a = _register_and_login(client, "updatera@example.com")
        headers_b = _register_and_login(client, "updaterb@example.com")

        create_response = client.post(
            "/api/backlog/entries",
            headers=headers_a,
            json={
                "title": "A's game",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )
        entry_id = create_response.json()["id"]

        response = client.put(
            f"/api/backlog/entries/{entry_id}",
            headers=headers_b,
            json={"title": "Hijacked"},
        )

    assert response.status_code == 404


def test_delete_entry_rejects_other_users_entry(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers_a = _register_and_login(client, "deletera@example.com")
        headers_b = _register_and_login(client, "deleterb@example.com")

        create_response = client.post(
            "/api/backlog/entries",
            headers=headers_a,
            json={
                "title": "A's game",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )
        entry_id = create_response.json()["id"]

        delete_response = client.delete(f"/api/backlog/entries/{entry_id}", headers=headers_b)
        still_there = client.get(f"/api/backlog/entries/{entry_id}", headers=headers_a)

    assert delete_response.status_code == 404
    assert still_there.status_code == 200


def test_update_entry_partial_update_leaves_other_fields_unchanged(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers = _register_and_login(client, "partialupdate@example.com")

        create_response = client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Celeste",
                "genre": ["Platformer"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
                "note": "great game",
            },
        )
        entry_id = create_response.json()["id"]

        update_response = client.put(
            f"/api/backlog/entries/{entry_id}",
            headers=headers,
            json={"status": "Completed"},
        )

    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["status"] == "Completed"
    assert updated["title"] == "Celeste"
    assert updated["note"] == "great game"


def test_get_entries_by_status_filters(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers = _register_and_login(client, "statusfilter@example.com")

        client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Not started game",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )
        client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Completed game",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Completed",
                "owned": True,
                "interest": 5,
            },
        )

        response = client.get(
            "/api/backlog/entries", headers=headers, params={"status": "Completed"}
        )

    assert response.status_code == 200
    titles = [entry["title"] for entry in response.json()]
    assert titles == ["Completed game"]


def test_category_crud_and_ownership(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers_a = _register_and_login(client, "categoryowner@example.com")
        headers_b = _register_and_login(client, "categoryintruder@example.com")

        create_response = client.post(
            "/api/backlog/categories",
            headers=headers_a,
            json={"category_name": "Favorites", "color": "#FF0000"},
        )
        assert create_response.status_code == 201
        category_id = create_response.json()["id"]

        forbidden_update = client.put(
            f"/api/backlog/categories/{category_id}",
            headers=headers_b,
            json={"category_name": "Hijacked"},
        )
        forbidden_delete = client.delete(
            f"/api/backlog/categories/{category_id}", headers=headers_b
        )

        own_update = client.put(
            f"/api/backlog/categories/{category_id}",
            headers=headers_a,
            json={"category_name": "Renamed"},
        )
        list_response = client.get("/api/backlog/categories", headers=headers_a)

    assert forbidden_update.status_code == 404
    assert forbidden_delete.status_code == 404
    assert own_update.status_code == 200
    assert own_update.json()["name"] == "Renamed"
    assert len(list_response.json()) == 1


def test_add_and_remove_category_from_entry(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers = _register_and_login(client, "associationowner@example.com")

        entry_id = client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Hollow Knight",
                "genre": ["Metroidvania"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 9,
            },
        ).json()["id"]
        category_id = client.post(
            "/api/backlog/categories",
            headers=headers,
            json={"category_name": "Favorites"},
        ).json()["id"]

        add_response = client.post(
            f"/api/backlog/entries/{entry_id}/categories/{category_id}", headers=headers
        )
        categories_for_entry = client.get(
            f"/api/backlog/entries/{entry_id}/categories", headers=headers
        )
        entries_for_category = client.get(
            f"/api/backlog/categories/{category_id}/entries", headers=headers
        )

        remove_response = client.delete(
            f"/api/backlog/entries/{entry_id}/categories/{category_id}", headers=headers
        )
        categories_for_entry_after_removal = client.get(
            f"/api/backlog/entries/{entry_id}/categories", headers=headers
        )

    assert add_response.status_code == 201
    assert len(categories_for_entry.json()) == 1
    assert categories_for_entry.json()[0]["id"] == category_id
    assert len(entries_for_category.json()) == 1
    assert entries_for_category.json()[0]["id"] == entry_id
    assert remove_response.status_code == 204
    assert categories_for_entry_after_removal.json() == []


def test_add_category_to_entry_rejects_other_users_category(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        headers_a = _register_and_login(client, "entryowner2@example.com")
        headers_b = _register_and_login(client, "categoryowner2@example.com")

        entry_id = client.post(
            "/api/backlog/entries",
            headers=headers_a,
            json={
                "title": "A's game",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        ).json()["id"]
        category_id = client.post(
            "/api/backlog/categories",
            headers=headers_b,
            json={"category_name": "B's category"},
        ).json()["id"]

        response = client.post(
            f"/api/backlog/entries/{entry_id}/categories/{category_id}", headers=headers_a
        )

    assert response.status_code == 404


def test_entry_routes_require_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import app

    with TestClient(app=app) as client:
        response = client.get("/api/backlog/entries")

    assert response.status_code == 401

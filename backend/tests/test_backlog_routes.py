from litestar.testing import TestClient


async def test_create_and_get_entry_round_trips(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "entryowner@example.com")

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


async def test_create_and_update_entry_playtime_round_trips(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "playtimeowner@example.com")

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
                "playtime": "3.5",
            },
        )
        assert create_response.status_code == 201
        entry_id = create_response.json()["id"]
        assert create_response.json()["playtime"] == "3.50"

        update_response = client.put(
            f"/api/backlog/entries/{entry_id}",
            headers=headers,
            json={"playtime": "12"},
        )

    assert update_response.status_code == 200
    assert update_response.json()["playtime"] == "12.00"


async def test_list_entries_only_returns_own_entries(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "usera@example.com")
        headers_b = await create_and_login(client, "userb@example.com")

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


async def test_get_entry_by_id_rejects_other_users_entry(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "ownera@example.com")
        headers_b = await create_and_login(client, "ownerb@example.com")

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


async def test_update_entry_rejects_other_users_entry(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "updatera@example.com")
        headers_b = await create_and_login(client, "updaterb@example.com")

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


async def test_delete_entry_rejects_other_users_entry(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "deletera@example.com")
        headers_b = await create_and_login(client, "deleterb@example.com")

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


async def test_delete_all_entries_removes_only_own_entries(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "deletealla@example.com")
        headers_b = await create_and_login(client, "deleteallb@example.com")

        for user_headers in (headers_a, headers_a, headers_b):
            client.post(
                "/api/backlog/entries",
                headers=user_headers,
                json={
                    "title": "Bulk delete test game",
                    "genre": ["RPG"],
                    "platform": ["PC"],
                    "status": "Not Started",
                    "owned": True,
                    "interest": 5,
                },
            )

        delete_response = client.delete("/api/backlog/entries", headers=headers_a)
        remaining_a = client.get("/api/backlog/entries", headers=headers_a)
        remaining_b = client.get("/api/backlog/entries", headers=headers_b)

    assert delete_response.status_code == 200
    assert delete_response.json() == 2
    assert remaining_a.json() == []
    assert len(remaining_b.json()) == 1


async def test_update_entry_partial_update_leaves_other_fields_unchanged(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "partialupdate@example.com")

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


async def test_get_entries_by_status_filters(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "statusfilter@example.com")

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


async def test_category_crud_and_ownership(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "categoryowner@example.com")
        headers_b = await create_and_login(client, "categoryintruder@example.com")

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


async def test_add_and_remove_category_from_entry(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "associationowner@example.com")

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


async def test_add_category_to_entry_rejects_other_users_category(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "entryowner2@example.com")
        headers_b = await create_and_login(client, "categoryowner2@example.com")

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
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        response = client.get("/api/backlog/entries")

    assert response.status_code == 401


async def test_create_entry_rejects_genre_containing_a_comma(
    postgres_url: str, create_and_login
) -> None:
    """Regression test: genre/platform are stored as one ", "-joined DB
    column, so a value containing that delimiter would silently split
    back into multiple values on the next read - must be rejected
    instead of persisted lossily."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "commaguard@example.com")

        response = client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Celeste",
                "genre": ["Action, Adventure"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )

    assert response.status_code == 400


async def test_update_entry_rejects_platform_containing_a_comma(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "commaguardupdate@example.com")

        entry_id = client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Celeste",
                "genre": ["Platformer"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        ).json()["id"]

        response = client.put(
            f"/api/backlog/entries/{entry_id}",
            headers=headers,
            json={"platform": ["PC, Steam Deck"]},
        )

    assert response.status_code == 400


async def test_get_duplicates_returns_matching_entries(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "dupeowner@example.com")

        client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                "title": "Elden Ring",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )

        duplicates_response = client.get(
            "/api/backlog/entries/duplicates",
            headers=headers,
            params={"title": "elden ring", "steam_app_id": 42},
        )

    assert duplicates_response.status_code == 200
    duplicates = duplicates_response.json()
    assert len(duplicates) == 1
    assert duplicates[0]["title"] == "Elden Ring"


async def test_get_duplicates_scoped_to_current_user(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers_a = await create_and_login(client, "dupesa@example.com")
        headers_b = await create_and_login(client, "dupesb@example.com")

        client.post(
            "/api/backlog/entries",
            headers=headers_a,
            json={
                "title": "Elden Ring",
                "genre": ["RPG"],
                "platform": ["PC"],
                "status": "Not Started",
                "owned": True,
                "interest": 5,
            },
        )

        duplicates_response = client.get(
            "/api/backlog/entries/duplicates",
            headers=headers_b,
            params={"title": "Elden Ring"},
        )

    assert duplicates_response.status_code == 200
    assert duplicates_response.json() == []


async def test_get_duplicates_requires_title(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "dupereq@example.com")

        duplicates_response = client.get(
            "/api/backlog/entries/duplicates",
            headers=headers,
        )

    assert duplicates_response.status_code == 400


async def test_create_category_rejects_invalid_color(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "badcategorycolor@example.com")
        responses = [
            client.post(
                "/api/backlog/categories",
                headers=headers,
                json={"category_name": "Bad", "color": color},
            )
            for color in ["red", "#fff", "#12345678", "url(javascript:alert(1))"]
        ]

    assert [response.status_code for response in responses] == [400, 400, 400, 400]


async def test_create_category_rejects_empty_and_overlong_name(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "badcategoryname@example.com")
        empty = client.post(
            "/api/backlog/categories", headers=headers, json={"category_name": ""}
        )
        too_long = client.post(
            "/api/backlog/categories", headers=headers, json={"category_name": "x" * 101}
        )

    assert empty.status_code == 400
    assert too_long.status_code == 400


async def test_update_category_rejects_invalid_color_and_name(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "badcategoryupdate@example.com")
        category_id = client.post(
            "/api/backlog/categories", headers=headers, json={"category_name": "Fine"}
        ).json()["id"]
        bad_color = client.put(
            f"/api/backlog/categories/{category_id}", headers=headers, json={"color": "blue"}
        )
        bad_name = client.put(
            f"/api/backlog/categories/{category_id}", headers=headers, json={"category_name": ""}
        )
        good = client.put(
            f"/api/backlog/categories/{category_id}",
            headers=headers,
            json={"color": "#00FF88", "category_name": "Renamed"},
        )

    assert bad_color.status_code == 400
    assert bad_name.status_code == 400
    assert good.status_code == 200
    assert good.json()["color"] == "#00FF88"


_ENTRY_BASE = {
    "title": "Hades",
    "genre": ["Roguelike"],
    "platform": ["PC"],
    "status": "Completed",
    "owned": True,
    "interest": 9,
}


async def test_review_stars_accept_the_full_zero_to_ten_range(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "tenstars@example.com")
        created = client.post(
            "/api/backlog/entries", headers=headers, json={**_ENTRY_BASE, "review_stars": 10}
        )
        entry_id = created.json()["id"]
        lowered = client.put(
            f"/api/backlog/entries/{entry_id}", headers=headers, json={"review_stars": 7}
        )
        cleared = client.put(
            f"/api/backlog/entries/{entry_id}", headers=headers, json={"review_stars": 0}
        )

    assert created.status_code == 201
    assert created.json()["review_stars"] == 10
    assert lowered.json()["review_stars"] == 7
    assert cleared.json()["review_stars"] == 0


async def test_review_stars_reject_values_outside_zero_to_ten(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "badstars@example.com")
        too_high_create = client.post(
            "/api/backlog/entries", headers=headers, json={**_ENTRY_BASE, "review_stars": 11}
        )
        negative_create = client.post(
            "/api/backlog/entries", headers=headers, json={**_ENTRY_BASE, "review_stars": -1}
        )
        entry_id = client.post(
            "/api/backlog/entries", headers=headers, json=_ENTRY_BASE
        ).json()["id"]
        too_high_update = client.put(
            f"/api/backlog/entries/{entry_id}", headers=headers, json={"review_stars": 11}
        )

    assert too_high_create.status_code == 400
    assert negative_create.status_code == 400
    assert too_high_update.status_code == 400

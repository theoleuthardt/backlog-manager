from litestar.testing import TestClient


def _create(client: TestClient, headers: dict, *, status: str, owned: bool) -> int:
    response = client.post(
        "/api/backlog/entries",
        headers=headers,
        json={
            "title": "Celeste",
            "genre": ["Platformer"],
            "platform": ["PC"],
            "status": status,
            "owned": owned,
            "interest": 5,
        },
    )
    assert response.status_code == 201
    return response.json()["id"]


def _update(client: TestClient, headers: dict, entry_id: int, body: dict) -> dict:
    response = client.put(f"/api/backlog/entries/{entry_id}", headers=headers, json=body)
    assert response.status_code == 200, response.text
    return response.json()


async def test_status_not_owned_marks_the_entry_as_not_owned(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership1@example.com")
        entry_id = _create(client, headers, status="In Progress", owned=True)

        updated = _update(client, headers, entry_id, {"status": "Not Owned"})

    assert updated["status"] == "Not Owned"
    assert updated["owned"] is False


async def test_moving_out_of_not_owned_marks_the_entry_as_owned(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership2@example.com")
        entry_id = _create(client, headers, status="Not Owned", owned=False)

        updated = _update(client, headers, entry_id, {"status": "In Progress"})

    assert updated["status"] == "In Progress"
    assert updated["owned"] is True


async def test_marking_an_entry_as_not_owned_sets_the_status(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership3@example.com")
        entry_id = _create(client, headers, status="In Progress", owned=True)

        updated = _update(client, headers, entry_id, {"owned": False})

    assert updated["owned"] is False
    assert updated["status"] == "Not Owned"


async def test_marking_a_not_owned_entry_as_owned_starts_it(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership4@example.com")
        entry_id = _create(client, headers, status="Not Owned", owned=False)

        updated = _update(client, headers, entry_id, {"owned": True})

    assert updated["owned"] is True
    assert updated["status"] == "Not Started"


async def test_an_explicit_status_and_ownership_are_kept_as_sent(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership5@example.com")
        entry_id = _create(client, headers, status="Not Owned", owned=False)

        updated = _update(client, headers, entry_id, {"status": "Completed", "owned": False})

    assert updated["status"] == "Completed"
    assert updated["owned"] is False


async def test_other_changes_leave_status_and_ownership_alone(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership6@example.com")
        entry_id = _create(client, headers, status="Not Owned", owned=False)

        updated = _update(client, headers, entry_id, {"note": "wishlist"})

    assert updated["status"] == "Not Owned"
    assert updated["owned"] is False


async def test_changing_between_ordinary_statuses_leaves_ownership_alone(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership7@example.com")
        entry_id = _create(client, headers, status="In Progress", owned=True)

        updated = _update(client, headers, entry_id, {"status": "Completed"})

    assert updated["status"] == "Completed"
    assert updated["owned"] is True


async def test_not_owned_cannot_be_created_as_a_custom_status(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "ownership8@example.com")

        response = client.post("/api/backlog/statuses", headers=headers, json={"name": "Not Owned"})

    assert response.status_code == 400

from litestar.testing import TestClient


async def test_csv_routes_require_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/csv/parse", json={"content": "a,b,c"})

    assert response.status_code == 401


async def test_parse_csv_splits_columns(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "csvparser@example.com")

        response = client.post(
            "/api/csv/parse",
            headers=headers,
            json={"content": "Celeste,Platformer,PC,Not Started"},
        )

    assert response.status_code == 200
    assert response.json() == [{"A": "Celeste", "B": "Platformer", "C": "PC", "D": "Not Started"}]


async def test_import_csv_creates_entries_and_reports_missing_games(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.integrations.types import HltbResultData

    async def fake_search(title: str) -> list[HltbResultData]:
        if title == "Celeste":
            return [
                HltbResultData(
                    id=1,
                    hltb_id=1,
                    title="Celeste",
                    image_url="https://example.com/celeste.jpg",
                    main_story=8.5,
                    main_story_with_extras=12.0,
                    completionist=37.0,
                    last_updated_at="2024-01-01",
                )
            ]
        return []

    monkeypatch.setattr("backlog_manager_backend.csv.parse_csv.search_game_on_hltb", fake_search)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "csvimporter@example.com")

        response = client.post(
            "/api/csv/import",
            headers=headers,
            json={
                "content": "Celeste,Platformer,PC,Not Started\nUnknown Game,RPG,PC,Not Started",
                "title_column": "A",
                "genre_column": "B",
                "platform_column": "C",
                "status_column": "D",
            },
        )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] == 1
    assert body["failed"] == 0
    assert len(body["missing_games"]) == 1
    assert body["missing_games"][0]["title"] == "Unknown Game"

    entries_response = client.get("/api/backlog/entries", headers=headers)
    assert entries_response.status_code == 200
    assert entries_response.json()[0]["title"] == "Celeste"


async def test_get_and_cancel_import_progress(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "csvprogress@example.com")

        initial = client.get("/api/csv/import/session-abc/progress", headers=headers)
        cancel_response = client.post("/api/csv/import/session-abc/cancel", headers=headers)

    assert initial.status_code == 200
    assert initial.json() == {"processed": 0}
    assert cancel_response.status_code == 204


async def test_import_session_progress_and_cancel_are_bound_to_their_owner(
    postgres_url: str, create_and_login
) -> None:
    """Regression test for an IDOR: the progress/cancel endpoints used
    to trust the client-supplied session_id alone, so any authenticated
    user could poll or cancel *another* user's in-progress CSV import
    just by guessing/knowing their session_id."""
    from backlog_manager_backend.app import create_app

    session_id = "owned-session-xyz"

    with TestClient(app=create_app()) as client:
        owner_headers = await create_and_login(client, "csvidorowner@example.com")
        intruder_headers = await create_and_login(client, "csvidorintruder@example.com")

        # Registers `session_id` as owned by the owner user (even a trivial,
        # zero-record import goes through import_backlog_entries_from_csv,
        # which is what records ownership).
        client.post(
            "/api/csv/import",
            headers=owner_headers,
            json={
                "content": "",
                "title_column": "A",
                "genre_column": "B",
                "platform_column": "C",
                "status_column": "D",
                "session_id": session_id,
            },
        )

        intruder_progress = client.get(
            f"/api/csv/import/{session_id}/progress", headers=intruder_headers
        )
        intruder_cancel = client.post(
            f"/api/csv/import/{session_id}/cancel", headers=intruder_headers
        )
        owner_progress = client.get(f"/api/csv/import/{session_id}/progress", headers=owner_headers)

    assert intruder_progress.status_code == 404
    assert intruder_cancel.status_code == 404
    assert owner_progress.status_code == 200


async def test_import_rejects_session_id_owned_by_another_user(
    postgres_url: str, create_and_login
) -> None:
    """Regression test: reusing another user's still-registered
    session_id used to silently reassign ownership to the new caller
    instead of being rejected."""
    from backlog_manager_backend.app import create_app

    session_id = "contested-session-xyz"

    with TestClient(app=create_app()) as client:
        owner_headers = await create_and_login(client, "csvcontestowner@example.com")
        intruder_headers = await create_and_login(client, "csvcontestintruder@example.com")

        client.post(
            "/api/csv/import",
            headers=owner_headers,
            json={
                "content": "",
                "title_column": "A",
                "genre_column": "B",
                "platform_column": "C",
                "status_column": "D",
                "session_id": session_id,
            },
        )

        intruder_import = client.post(
            "/api/csv/import",
            headers=intruder_headers,
            json={
                "content": "",
                "title_column": "A",
                "genre_column": "B",
                "platform_column": "C",
                "status_column": "D",
                "session_id": session_id,
            },
        )

    assert intruder_import.status_code == 409

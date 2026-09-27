import json

import pytest
from litestar.testing import TestClient


def _parse_sse(body: str) -> list[tuple[str | None, str]]:
    """Mirrors test_steam_routes.py's _parse_sse - see its docstring."""
    messages: list[tuple[str | None, str]] = []
    for raw_message in body.strip("\r\n").split("\r\n\r\n"):
        event: str | None = None
        data_lines: list[str] = []
        for line in raw_message.split("\r\n"):
            if line.startswith("event: "):
                event = line.removeprefix("event: ")
            elif line.startswith("data: "):
                data_lines.append(line.removeprefix("data: "))
        if data_lines:
            messages.append((event, "\n".join(data_lines)))
    return messages


async def test_csv_routes_require_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        response = client.post("/api/csv/headers", json={"content": "a,b,c"})

    assert response.status_code == 401


async def test_get_csv_headers_reads_first_row(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "csvheaders@example.com")

        response = client.post(
            "/api/csv/headers",
            headers=headers,
            json={
                "content": "Game,Genre,Platform,Status\nCeleste,Platformer,PC,Not Started",
                "title_column": "A",
                "genre_column": "B",
                "platform_column": "C",
                "status_column": "D",
            },
        )

    assert response.status_code == 200
    assert response.json() == {"headers": {"A": "Game", "B": "Genre", "C": "Platform", "D": "Status"}}


async def test_preview_csv_stream_reports_progress_then_done(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    """IGDB credentials are cleared so this stays HowLongToBeat-only
    regardless of what this machine's own .env has configured -
    IGDB-specific matching is covered separately in test_csv_preview.py."""
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.integrations.types import HltbResultData

    monkeypatch.setattr(settings, "igdb_client_id", None)
    monkeypatch.setattr(settings, "igdb_client_secret", None)

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

    monkeypatch.setattr("backlog_manager_backend.csv.preview.search_game_on_hltb", fake_search)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "csvpreviewstream@example.com")

        response = client.post(
            "/api/csv/preview/stream",
            headers=headers,
            json={
                "content": (
                    "Game,Genre,Platform,Status\n"
                    "Celeste,Platformer,Owned,Finished\n"
                    "Unknown Game,RPG,Owned,\n"
                ),
                "title_column": "A",
                "genre_column": "B",
                "platform_column": "C",
                "status_column": "D",
            },
        )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    messages = _parse_sse(response.text)

    progress_events = [json.loads(data) for event, data in messages if event == "progress"]
    assert progress_events == [{"processed": 1, "total": 2}, {"processed": 2, "total": 2}]

    done_events = [json.loads(data) for event, data in messages if event == "done"]
    assert len(done_events) == 1
    items = done_events[0]
    assert len(items) == 2
    celeste = next(item for item in items if item["title"] == "Celeste")
    assert celeste["status"] == "Completed"
    assert celeste["platform"] == ["PC"]
    assert celeste["matched"] is True
    unknown = next(item for item in items if item["title"] == "Unknown Game")
    assert unknown["matched"] is False


async def test_submit_csv_stream_creates_entries(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "csvsubmitstream@example.com")

        response = client.post(
            "/api/csv/submit/stream",
            headers=headers,
            json=[
                {
                    "title": "Celeste",
                    "genre": "Platformer",
                    "platform": ["PC"],
                    "status": "Completed",
                    "owned": True,
                    "playtime": "12.5",
                    "review_stars": 9,
                    "completed_at": "2026-07-01T00:00:00",
                }
            ],
        )

        entries_response = client.get("/api/backlog/entries", headers=headers)

    assert response.status_code == 200
    messages = _parse_sse(response.text)
    done_events = [json.loads(data) for event, data in messages if event == "done"]
    assert len(done_events) == 1
    assert done_events[0][0]["title"] == "Celeste"
    assert done_events[0][0]["status"] == "Completed"

    assert entries_response.status_code == 200
    assert entries_response.json()[0]["title"] == "Celeste"

import json

import pytest
from litestar.testing import TestClient

from backlog_manager_backend.integrations.types import EnrichedResult


def _parse_sse(body: str) -> list[tuple[str | None, str]]:
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


def _entry_body(title: str, **overrides: object) -> dict[str, object]:
    return {
        "title": title,
        "genre": [],
        "platform": ["PC"],
        "status": "Not Started",
        "owned": True,
        "interest": 5,
        **overrides,
    }


def _configure_igdb(monkeypatch: pytest.MonkeyPatch, configured: bool = True) -> None:
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "igdb_client_id", "cid" if configured else None)
    monkeypatch.setattr(settings, "igdb_client_secret", "secret" if configured else None)


async def test_pending_count_lists_entries_missing_igdb_data(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_igdb(monkeypatch)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "igdbcount@example.com")
        client.post("/api/backlog/entries", headers=headers, json=_entry_body("Needs data"))
        client.post(
            "/api/backlog/entries",
            headers=headers,
            json=_entry_body("Complete", genre=["RPG"], description="Done"),
        )

        response = client.get("/api/igdb-sync/pending-count", headers=headers)

    assert response.status_code == 200
    assert response.json() == 1


async def test_igdb_sync_stream_requires_igdb_credentials(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_igdb(monkeypatch, configured=False)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "igdbnocreds@example.com")
        response = client.post("/api/igdb-sync/stream", headers=headers)

    assert response.status_code == 503


async def test_igdb_sync_stream_reports_progress_then_the_updated_entries(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.services import game_service

    _configure_igdb(monkeypatch)

    async def fake_search(title: str, *args: object, **kwargs: object) -> list[EnrichedResult]:
        return [
            EnrichedResult(
                id=1,
                hltb_id=1,
                title=title,
                image_url=None,
                genres=["RPG"],
                platforms=[],
                main_story=10.0,
                main_story_with_extras=20.0,
                completionist=40.0,
                description="From IGDB",
            )
        ]

    monkeypatch.setattr(game_service, "search", fake_search)

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "igdbstream@example.com")
        client.post("/api/backlog/entries", headers=headers, json=_entry_body("Needs data"))

        response = client.post("/api/igdb-sync/stream", headers=headers)

    assert response.status_code == 200
    messages = _parse_sse(response.text)
    assert [json.loads(data) for event, data in messages if event == "progress"] == [
        {"processed": 1, "total": 1}
    ]
    [done] = [json.loads(data) for event, data in messages if event == "done"]
    assert done[0]["genre"] == ["RPG"]
    assert done[0]["description"] == "From IGDB"

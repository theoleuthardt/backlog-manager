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
            json=_entry_body("Complete", genre=["RPG"], description="Done", publisher="Label"),
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


def _make_space(client: TestClient, owner: dict, guest: dict, guest_name: str) -> int:
    invite = client.post("/api/space/invitations", headers=owner, json={"username": guest_name})
    assert invite.status_code == 201
    accept = client.post("/api/space/invitations/accept", headers=guest)
    assert accept.status_code == 200
    return accept.json()["space_id"]


async def test_pending_count_can_count_the_entries_of_a_space(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_igdb(monkeypatch)

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "igdbspaceowner@example.com")
        guest = await create_and_login(client, "igdbspaceguest@example.com")
        space_id = _make_space(client, owner, guest, "igdbspaceguest")
        client.post(
            f"/api/backlog/entries?space_id={space_id}",
            headers=owner,
            json=_entry_body("Space game needs data"),
        )
        client.post("/api/backlog/entries", headers=owner, json=_entry_body("Mine needs data"))
        client.post("/api/backlog/entries", headers=owner, json=_entry_body("Mine too"))

        in_space = client.get(f"/api/igdb-sync/pending-count?space_id={space_id}", headers=guest)
        personal = client.get("/api/igdb-sync/pending-count", headers=owner)

    assert in_space.json() == 1
    assert personal.json() == 2


async def test_a_non_member_cannot_use_the_igdb_sync_of_a_space(
    postgres_url: str, create_and_login, monkeypatch: pytest.MonkeyPatch
) -> None:
    from backlog_manager_backend.app import create_app

    _configure_igdb(monkeypatch)

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "igdbspacemember@example.com")
        guest = await create_and_login(client, "igdbspacemember2@example.com")
        outsider = await create_and_login(client, "igdbspaceoutsider@example.com")
        space_id = _make_space(client, owner, guest, "igdbspacemember2")

        count = client.get(f"/api/igdb-sync/pending-count?space_id={space_id}", headers=outsider)
        stream = client.post(f"/api/igdb-sync/stream?space_id={space_id}", headers=outsider)

    assert count.status_code == 404
    assert stream.status_code == 404


async def test_igdb_sync_stream_updates_the_entries_of_a_space(
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
                genres=["Co-op"],
                platforms=[],
                main_story=10.0,
                main_story_with_extras=20.0,
                completionist=40.0,
                description="From IGDB",
            )
        ]

    monkeypatch.setattr(game_service, "search", fake_search)

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "igdbspacestream@example.com")
        guest = await create_and_login(client, "igdbspacestream2@example.com")
        space_id = _make_space(client, owner, guest, "igdbspacestream2")
        client.post(
            f"/api/backlog/entries?space_id={space_id}",
            headers=owner,
            json=_entry_body("Space needs data"),
        )
        client.post("/api/backlog/entries", headers=owner, json=_entry_body("Personal untouched"))

        response = client.post(f"/api/igdb-sync/stream?space_id={space_id}", headers=guest)
        personal = client.get("/api/backlog/entries", headers=owner).json()

    messages = _parse_sse(response.text)
    [done] = [json.loads(data) for event, data in messages if event == "done"]
    assert [entry["title"] for entry in done] == ["Space needs data"]
    assert done[0]["genre"] == ["Co-op"]
    assert personal[0]["genre"] == []

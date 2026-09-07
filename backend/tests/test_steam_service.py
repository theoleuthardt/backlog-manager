from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.integrations.types import SteamOwnedGame
from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.user import CreateUserParams
from backlog_manager_backend.services import steam_service


async def _make_user(session: AsyncSession, steam_id: str | None = "76561197960287930") -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(
            username="steamuser", email="steamuser@example.com", password_hash="h", steam_id=steam_id
        ),
    )


async def _make_entry(session: AsyncSession, user_id: int, **overrides: object) -> object:
    return await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user_id,
            title=overrides.get("title", "Celeste"),
            genre="Platformer",
            platform="PC",
            status="In Progress",
            owned=True,
            interest=8,
            steam_app_id=overrides.get("steam_app_id"),
            playtime=overrides.get("playtime"),
        ),
    )


async def test_sync_playtimes_raises_when_steam_not_linked(session: AsyncSession) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.sync_playtimes(session, user, "api-key")


async def test_sync_playtimes_updates_matching_entries(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    matching = await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("1.00"))
    await _make_entry(session, user.id, title="No Steam Link", steam_app_id=None)
    await _make_entry(session, user.id, title="Not Owned On Steam", steam_app_id=999)

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        assert steam_id == user.steam_id
        assert api_key == "api-key"
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert len(updated) == 1
    assert updated[0].backlog_entry_id == matching.backlog_entry_id
    assert updated[0].playtime == Decimal("8.50")


async def test_sync_playtimes_skips_entries_already_up_to_date(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("8.50"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    updated = await steam_service.sync_playtimes(session, user, "api-key")

    assert updated == []


async def test_import_library_raises_when_steam_not_linked(session: AsyncSession) -> None:
    user = await _make_user(session, steam_id=None)

    with pytest.raises(ValidationError):
        await steam_service.import_library(session, user, "api-key")


async def test_import_library_creates_entries_for_new_owned_games(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("8.50"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        assert steam_id == user.steam_id
        assert api_key == "api-key"
        return [
            SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510),
            SteamOwnedGame(appid=620, name="Portal 2", playtime_forever=120),
        ]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(session, user, "api-key")

    assert len(created) == 1
    assert created[0].title == "Portal 2"
    assert created[0].steam_app_id == 620
    assert created[0].playtime == Decimal("2.00")
    assert created[0].status == "Not Started"
    assert created[0].owned is True


async def test_import_library_creates_nothing_when_all_games_already_linked(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await _make_entry(session, user.id, steam_app_id=504230, playtime=Decimal("8.50"))

    async def fake_get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
        return [SteamOwnedGame(appid=504230, name="Celeste", playtime_forever=510)]

    monkeypatch.setattr(steam_service, "get_owned_games", fake_get_owned_games)

    created = await steam_service.import_library(session, user, "api-key")

    assert created == []

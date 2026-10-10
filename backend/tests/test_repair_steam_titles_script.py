import importlib.util
from pathlib import Path

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import SteamAppDetails
from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.user import CreateUserParams
from backlog_manager_backend.services import steam_service

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "repair_steam_titles.py"


def _load_script() -> object:
    spec = importlib.util.spec_from_file_location("repair_steam_titles", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


async def _user_with_unnamed_entry(session: AsyncSession) -> int:
    user = await user_repo.create_user(
        session,
        CreateUserParams(
            username="repair", email="repair@example.com", password_hash="h", steam_id="1"
        ),
    )
    await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user.id,
            title="620",
            genre="",
            platform="PC",
            status="Not Owned",
            owned=False,
            interest=5,
            steam_app_id=620,
        ),
    )
    return user.id


@pytest.fixture
def stores_name(monkeypatch: pytest.MonkeyPatch) -> None:
    async def fake_details(app_ids: list[int], budget: object = None) -> dict[int, SteamAppDetails]:
        return {620: SteamAppDetails(name="Portal 2", header_image=None)}

    async def no_cover(app_id: int, key: str | None) -> str | None:
        return None

    monkeypatch.setattr(steam_service, "_get_steam_app_details", fake_details)
    monkeypatch.setattr(steam_service, "_try_get_cover", no_cover)


async def test_the_script_only_reports_without_apply(
    session: AsyncSession, stores_name: None
) -> None:
    script = _load_script()
    user_id = await _user_with_unnamed_entry(session)

    repairs = await script.run(session, user_id, apply=False)

    assert [(r.old_title, r.new_title) for r in repairs] == [("620", "Portal 2")]
    [entry] = await backlog_entry_repo.get_backlog_entries_by_user(session, user_id)
    assert entry.title == "620"
    assert "Would repair 1 of 1 entries." in script.format_report(repairs, apply=False)


async def test_the_script_repairs_with_apply(session: AsyncSession, stores_name: None) -> None:
    script = _load_script()
    user_id = await _user_with_unnamed_entry(session)

    repairs = await script.run(session, user_id, apply=True)

    [entry] = await backlog_entry_repo.get_backlog_entries_by_user(session, user_id)
    assert entry.title == "Portal 2"
    assert "620: '620' -> 'Portal 2'" in script.format_report(repairs, apply=True)
    assert "Repaired 1 of 1 entries." in script.format_report(repairs, apply=True)

from decimal import Decimal
from types import ModuleType

import msgspec
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, ValidationError
from backlog_manager_backend.repositories import (
    backlog_entry_repo,
    category_backlog_entry_repo,
    category_repo,
    custom_status_repo,
    user_repo,
)
from backlog_manager_backend.schemas.backlog_entry import (
    CategoryBacklogAssociationParams,
    CreateBacklogEntryParams,
    UpdateBacklogEntryParams,
)
from backlog_manager_backend.schemas.category import CreateCategoryParams
from backlog_manager_backend.schemas.custom_status import CreateCustomStatusParams
from backlog_manager_backend.schemas.user import CreateUserParams


@pytest.fixture
def backup_service() -> ModuleType:
    from backlog_manager_backend.services import backup_service as module

    return module


async def _make_user(session: AsyncSession, username: str):
    return await user_repo.create_user(
        session,
        CreateUserParams(username=username, email=f"{username}@example.com", password_hash="h"),
    )


async def _make_entry(session: AsyncSession, user_id: int, title: str, **overrides: object):
    return await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user_id,
            title=title,
            genre="RPG",
            platform="PC",
            status=overrides.get("status", "Not Started"),
            owned=True,
            interest=7,
            steam_app_id=overrides.get("steam_app_id"),
            note=overrides.get("note"),
            playtime=overrides.get("playtime"),
        ),
    )


async def _seed(session: AsyncSession, user_id: int) -> None:
    """Two entries, one category linking the first, one custom status."""
    first = await _make_entry(session, user_id, "Hades", steam_app_id=1145360, note="great")
    await _make_entry(session, user_id, "Celeste")
    category = await category_repo.create_category(
        session,
        CreateCategoryParams(
            user_id=user_id, category_name="Roguelikes", color="#ff0000", description="runs"
        ),
    )
    await category_backlog_entry_repo.add_category_to_backlog_entry(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=first.backlog_entry_id
        ),
    )
    await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=user_id, name="Parked")
    )


async def _state(session: AsyncSession, user_id: int) -> dict:
    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user_id)
    categories = await category_repo.get_categories_by_user(session, user_id)
    statuses = await custom_status_repo.get_custom_statuses_by_user(session, user_id)
    links = {}
    for category in categories:
        linked = await backlog_entry_repo.get_backlog_entries_for_category(
            session, category.category_id
        )
        links[category.name] = sorted(entry.title for entry in linked)
    return {
        "entries": sorted((e.title, e.status, e.note, e.steam_app_id) for e in entries),
        "categories": sorted((c.name, c.color, c.description) for c in categories),
        "links": links,
        "statuses": sorted(s.name for s in statuses),
    }


async def test_create_backup_snapshots_entries_categories_links_and_statuses(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "snapshotuser")
    await _seed(session, user.id)

    backup = await backup_service.create_manual_backup(session, user.id)

    assert backup.kind == "manual"
    assert backup.entry_count == 2
    assert backup.category_count == 1


async def test_backup_payload_contains_no_user_identifiers_or_secrets(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "payloaduser")
    await _seed(session, user.id)
    backup = await backup_service.create_manual_backup(session, user.id)

    exported = await backup_service.export_backup(session, user.id, backup.id)
    text = msgspec.json.encode(exported).decode()

    assert "user_id" not in text
    assert "password" not in text


async def test_auto_backup_is_skipped_for_an_empty_backlog(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "emptyauto")

    assert await backup_service.create_backup(session, user.id, "auto") is None
    assert await backup_service.list_backups(session, user.id) == []


async def test_auto_backup_is_skipped_when_nothing_changed_since_the_latest_backup(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "dedupeauto")
    await _seed(session, user.id)

    first = await backup_service.create_backup(session, user.id, "auto")
    second = await backup_service.create_backup(session, user.id, "auto")

    assert first is not None
    assert second is None
    assert len(await backup_service.list_backups(session, user.id)) == 1


async def test_auto_backup_is_created_again_once_the_data_changed(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "changedauto")
    await _seed(session, user.id)
    await backup_service.create_backup(session, user.id, "auto")
    await _make_entry(session, user.id, "Tunic")

    second = await backup_service.create_backup(session, user.id, "auto")

    assert second is not None
    assert second.entry_count == 3


async def test_manual_backup_is_created_even_when_nothing_changed(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "manualdupe")
    await _seed(session, user.id)

    await backup_service.create_manual_backup(session, user.id)
    second = await backup_service.create_manual_backup(session, user.id)

    assert second is not None
    assert len(await backup_service.list_backups(session, user.id)) == 2


async def test_list_backups_returns_newest_first(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "listorder")
    await _seed(session, user.id)
    first = await backup_service.create_manual_backup(session, user.id)
    second = await backup_service.create_manual_backup(session, user.id)

    backups = await backup_service.list_backups(session, user.id)

    assert [backup.id for backup in backups] == [second.id, first.id]


async def test_restore_brings_back_the_backed_up_state(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "restoreuser")
    await _seed(session, user.id)
    original_state = await _state(session, user.id)
    backup = await backup_service.create_manual_backup(session, user.id)

    await backlog_entry_repo.delete_backlog_entries_by_user(session, user.id)
    await _make_entry(session, user.id, "Something else", steam_app_id=1)
    categories = await category_repo.get_categories_by_user(session, user.id)
    await category_repo.delete_category(session, categories[0].category_id)
    statuses = await custom_status_repo.get_custom_statuses_by_user(session, user.id)
    await custom_status_repo.delete_custom_status(session, statuses[0].status_id)

    result = await backup_service.restore_backup(session, user.id, backup.id)

    assert result.entry_count == 2
    assert result.category_count == 1
    assert await _state(session, user.id) == original_state


async def test_restore_keeps_timestamps_and_review_fields(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "restorefields")
    entry = await _make_entry(session, user.id, "Hades", steam_app_id=1145360)
    await backlog_entry_repo.update_backlog_entry(
        session,
        UpdateBacklogEntryParams(
            backlog_entry_id=entry.backlog_entry_id,
            status="Completed",
            review_stars=5,
            review="loved it",
            playtime=Decimal(42),
        ),
    )
    before = (await backlog_entry_repo.get_backlog_entries_by_user(session, user.id))[0]
    backup = await backup_service.create_manual_backup(session, user.id)
    await backlog_entry_repo.delete_backlog_entries_by_user(session, user.id)

    await backup_service.restore_backup(session, user.id, backup.id)

    after = (await backlog_entry_repo.get_backlog_entries_by_user(session, user.id))[0]
    assert (after.status, after.review_stars, after.review, after.playtime) == (
        before.status,
        before.review_stars,
        before.review,
        before.playtime,
    )
    assert after.completed_at == before.completed_at
    assert after.created_at == before.created_at


async def test_restore_first_takes_a_safety_backup_that_undoes_the_restore(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "undorestore")
    await _seed(session, user.id)
    old_backup = await backup_service.create_manual_backup(session, user.id)
    await _make_entry(session, user.id, "Added later")
    state_before_restore = await _state(session, user.id)

    result = await backup_service.restore_backup(session, user.id, old_backup.id)
    await backup_service.restore_backup(session, user.id, result.safety_backup_id)

    assert result.safety_backup_id is not None
    assert await _state(session, user.id) == state_before_restore


async def test_restore_leaves_other_users_untouched(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "restoreme")
    other = await _make_user(session, "bystander")
    await _seed(session, user.id)
    await _make_entry(session, other.id, "Bystander game")
    backup = await backup_service.create_manual_backup(session, user.id)
    other_state = await _state(session, other.id)

    await backup_service.restore_backup(session, user.id, backup.id)

    assert await _state(session, other.id) == other_state


async def test_restore_rejects_another_users_backup(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    owner = await _make_user(session, "backupowner")
    intruder = await _make_user(session, "backupintruder")
    await _seed(session, owner.id)
    backup = await backup_service.create_manual_backup(session, owner.id)

    with pytest.raises(NotFoundError):
        await backup_service.restore_backup(session, intruder.id, backup.id)


async def test_restore_rejects_an_unsupported_payload_version_and_changes_nothing(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.models.user_backup import UserBackup

    user = await _make_user(session, "badversion")
    await _seed(session, user.id)
    backup = await backup_service.create_manual_backup(session, user.id)
    model = await session.get(UserBackup, backup.id)
    model.payload = {**model.payload, "version": 999}
    await session.commit()
    state_before = await _state(session, user.id)

    with pytest.raises(ValidationError):
        await backup_service.restore_backup(session, user.id, backup.id)

    assert await _state(session, user.id) == state_before


async def test_restore_rejects_a_payload_that_violates_the_schema_and_changes_nothing(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.models.user_backup import UserBackup

    user = await _make_user(session, "badpayload")
    await _seed(session, user.id)
    backup = await backup_service.create_manual_backup(session, user.id)
    model = await session.get(UserBackup, backup.id)
    entries = [{**entry, "interest": 99} for entry in model.payload["entries"]]
    model.payload = {**model.payload, "entries": entries}
    await session.commit()
    state_before = await _state(session, user.id)

    with pytest.raises(ValidationError):
        await backup_service.restore_backup(session, user.id, backup.id)

    assert await _state(session, user.id) == state_before


async def test_restore_rolls_back_completely_when_the_database_rejects_the_data(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.errors import ConflictError
    from backlog_manager_backend.models.user_backup import UserBackup

    user = await _make_user(session, "dbreject")
    await _make_entry(session, user.id, "One", steam_app_id=10)
    await _make_entry(session, user.id, "Two", steam_app_id=20)
    backup = await backup_service.create_manual_backup(session, user.id)
    model = await session.get(UserBackup, backup.id)
    entries = [{**entry, "steam_app_id": 10} for entry in model.payload["entries"]]
    model.payload = {**model.payload, "entries": entries}
    await session.commit()
    state_before = await _state(session, user.id)

    with pytest.raises(ConflictError):
        await backup_service.restore_backup(session, user.id, backup.id)

    assert await _state(session, user.id) == state_before


async def test_old_backups_beyond_the_retention_limit_are_pruned(
    backup_service: ModuleType, session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setitem(backup_service.RETENTION, "auto", 2)
    user = await _make_user(session, "pruneuser")
    await _seed(session, user.id)
    created = []
    for index in range(3):
        await _make_entry(session, user.id, f"Extra {index}")
        created.append(await backup_service.create_backup(session, user.id, "auto"))

    backups = await backup_service.list_backups(session, user.id)

    assert [backup.id for backup in backups] == [created[2].id, created[1].id]


async def test_retention_is_counted_per_kind(
    backup_service: ModuleType, session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setitem(backup_service.RETENTION, "auto", 1)
    user = await _make_user(session, "prunekinds")
    await _seed(session, user.id)
    manual = await backup_service.create_manual_backup(session, user.id)
    await _make_entry(session, user.id, "Extra")
    await backup_service.create_backup(session, user.id, "auto")
    await _make_entry(session, user.id, "Extra 2")
    await backup_service.create_backup(session, user.id, "auto")

    kinds = [backup.kind for backup in await backup_service.list_backups(session, user.id)]

    assert sorted(kinds) == ["auto", "manual"]
    assert manual.id in [b.id for b in await backup_service.list_backups(session, user.id)]


async def test_delete_backup_removes_it(backup_service: ModuleType, session: AsyncSession) -> None:
    user = await _make_user(session, "deletebackup")
    await _seed(session, user.id)
    backup = await backup_service.create_manual_backup(session, user.id)

    await backup_service.delete_backup(session, user.id, backup.id)

    assert await backup_service.list_backups(session, user.id) == []


async def test_delete_backup_rejects_another_users_backup(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    owner = await _make_user(session, "delowner")
    intruder = await _make_user(session, "delintruder")
    await _seed(session, owner.id)
    backup = await backup_service.create_manual_backup(session, owner.id)

    with pytest.raises(NotFoundError):
        await backup_service.delete_backup(session, intruder.id, backup.id)


async def test_scheduled_run_backs_up_users_that_are_due(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    due = await _make_user(session, "scheduledue")
    empty = await _make_user(session, "scheduleempty")
    await _seed(session, due.id)

    await backup_service.create_due_auto_backups(session)

    assert [b.kind for b in await backup_service.list_backups(session, due.id)] == ["auto"]
    assert await backup_service.list_backups(session, empty.id) == []


async def test_scheduled_run_does_not_back_up_again_within_the_interval(
    backup_service: ModuleType, session: AsyncSession
) -> None:
    user = await _make_user(session, "schedulerepeat")
    await _seed(session, user.id)
    await backup_service.create_due_auto_backups(session)
    await _make_entry(session, user.id, "Changed afterwards")

    await backup_service.create_due_auto_backups(session)

    assert len(await backup_service.list_backups(session, user.id)) == 1

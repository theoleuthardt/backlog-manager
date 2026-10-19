from datetime import timedelta
from types import ModuleType

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, NotFoundError
from backlog_manager_backend.repositories import (
    backlog_entry_repo,
    category_backlog_entry_repo,
    category_repo,
    custom_status_repo,
    entry_mod_repo,
    space_entry_member_repo,
    space_repo,
    user_repo,
)
from backlog_manager_backend.schemas.backlog_entry import (
    CategoryBacklogAssociationParams,
    CreateBacklogEntryParams,
)
from backlog_manager_backend.schemas.category import CreateCategoryParams
from backlog_manager_backend.schemas.custom_status import CreateCustomStatusParams
from backlog_manager_backend.schemas.user import CreateUserParams, User


@pytest.fixture
def service() -> ModuleType:
    from backlog_manager_backend.services import space_backup_service as module

    return module


async def _make_user(session: AsyncSession, username: str) -> User:
    return await user_repo.create_user(
        session,
        CreateUserParams(username=username, email=f"{username}@example.com", password_hash="h"),
    )


async def _make_space(session: AsyncSession, prefix: str) -> tuple[int, User, User]:
    first = await _make_user(session, f"{prefix}one")
    second = await _make_user(session, f"{prefix}two")
    space_id = await space_repo.create_space(session, first.id)
    await space_repo.add_invited_member(session, space_id, second.id)
    await space_repo.activate_member(session, space_id, second.id)
    return space_id, first, second


async def _seed(session: AsyncSession, space_id: int, first: User, second: User) -> int:
    entry = await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=first.id,
            title="Deep Rock Galactic",
            genre="Co-op",
            platform="PC",
            status="Not Started",
            owned=True,
            interest=8,
            steam_app_id=548430,
            space_id=space_id,
        ),
    )
    entry_id = entry.backlog_entry_id
    category = await category_repo.create_category(
        session,
        CreateCategoryParams(user_id=first.id, category_name="Co-op night", space_id=space_id),
    )
    await category_backlog_entry_repo.add_category_to_backlog_entry(
        session,
        CategoryBacklogAssociationParams(
            category_id=category.category_id, backlog_entry_id=entry_id
        ),
    )
    await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=first.id, name="Weekend", space_id=space_id)
    )
    await entry_mod_repo.create_mod(session, entry_id, "Better HUD", "https://example.com/hud")
    await space_entry_member_repo.upsert_member_data(
        session, entry_id, first.id, review_stars=4, review="Great with friends", owned=True
    )
    await space_entry_member_repo.upsert_member_data(
        session, entry_id, second.id, review_stars=2, review="Too grindy", owned=False
    )
    return entry_id


async def _wipe_entries(session: AsyncSession, space_id: int) -> None:
    await backlog_entry_repo.delete_backlog_entries_by_space(session, space_id)


async def _member_reviews(session: AsyncSession, space_id: int) -> dict[int, str | None]:
    result = await session.execute(
        text(
            'SELECT d."UserID", d."Review" FROM "blm-system"."SpaceEntryMemberData" d '
            'JOIN "blm-system"."BacklogEntries" e ON e."BacklogEntryID" = d."BacklogEntryID" '
            'WHERE e."SpaceID" = :space_id'
        ),
        {"space_id": space_id},
    )
    return {user_id: review for user_id, review in result.all()}


async def test_manual_backup_holds_everything_of_the_space(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "full")
    await _seed(session, space_id, first, second)

    summary = await service.create_manual_backup(session, second)
    stored = await service.space_backup_repo.get_backup(session, space_id, summary.id)

    assert (summary.kind, summary.entry_count, summary.category_count) == ("manual", 1, 1)
    assert summary.created_by == "fulltwo"
    payload = service._decode_payload(stored.payload)
    assert [entry.title for entry in payload.entries] == ["Deep Rock Galactic"]
    assert [mod.name for mod in payload.entries[0].mods] == ["Better HUD"]
    assert [status.name for status in payload.custom_statuses] == ["Weekend"]
    assert {row.user_id: row.review for row in payload.member_data} == {
        first.id: "Great with friends",
        second.id: "Too grindy",
    }


async def test_a_user_without_an_active_membership_cannot_use_the_backups(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, _, _ = await _make_space(session, "outsider")
    stranger = await _make_user(session, "outsiderthree")
    invited = await _make_user(session, "outsiderfour")
    await space_repo.lock_space(session, space_id)
    await space_repo.add_invited_member(session, space_id, invited.id)

    for user in (stranger, invited):
        with pytest.raises(NotFoundError):
            await service.list_backups(session, user)
        with pytest.raises(NotFoundError):
            await service.create_manual_backup(session, user)
        with pytest.raises(NotFoundError):
            await service.export_space(session, user)


async def test_the_backups_of_another_space_are_not_found(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "isoa")
    other_id, other_first, _ = await _make_space(session, "isob")
    await _seed(session, space_id, first, second)
    foreign = await service.create_manual_backup(session, first)

    with pytest.raises(NotFoundError):
        await service.request_restore(session, other_first, foreign.id)
    with pytest.raises(NotFoundError):
        await service.export_backup(session, other_first, foreign.id)
    with pytest.raises(NotFoundError):
        await service.delete_backup(session, other_first, foreign.id)
    assert other_id != space_id


async def test_a_restore_waits_for_the_other_member_and_changes_nothing_before(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "wait")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await _wipe_entries(session, space_id)

    response = await service.request_restore(session, first, backup.id)

    assert response.restored is False
    assert response.result is None
    assert response.request is not None
    assert response.request.backup_id == backup.id
    assert response.request.requested_by == "waitone"
    assert response.request.requested_by_me is True
    assert response.request.expires_at - response.request.created_at == timedelta(hours=24)
    assert await backlog_entry_repo.get_backlog_entries_by_space(session, space_id) == []
    partner_view = (await service.list_backups(session, second)).restore_request
    assert partner_view is not None
    assert partner_view.requested_by_me is False


async def test_the_member_who_asked_cannot_approve_their_own_restore(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "self")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await service.request_restore(session, first, backup.id)

    with pytest.raises(ConflictError):
        await service.approve_restore(session, first)


async def test_approving_restores_the_content_and_both_members_data(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "approve")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await _wipe_entries(session, space_id)
    await service.request_restore(session, first, backup.id)

    result = await service.approve_restore(session, second)

    entries = await backlog_entry_repo.get_backlog_entries_by_space(session, space_id)
    assert [entry.title for entry in entries] == ["Deep Rock Galactic"]
    assert (result.entry_count, result.category_count) == (1, 1)
    assert await _member_reviews(session, space_id) == {
        first.id: "Great with friends",
        second.id: "Too grindy",
    }
    assert [
        category.name for category in await category_repo.get_categories_by_space(session, space_id)
    ] == ["Co-op night"]
    assert (await service.list_backups(session, first)).restore_request is None


async def test_a_restore_takes_a_safety_snapshot_of_the_current_state_first(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "safety")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await backlog_entry_repo.delete_backlog_entries_by_space(session, space_id)
    await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=second.id,
            title="Newer game",
            genre="RPG",
            platform="PC",
            status="Not Started",
            owned=True,
            interest=3,
            space_id=space_id,
        ),
    )
    await service.request_restore(session, first, backup.id)

    result = await service.approve_restore(session, second)

    assert result.safety_backup_id is not None
    safety = await service.space_backup_repo.get_backup(session, space_id, result.safety_backup_id)
    assert safety.kind == "pre-restore"
    assert [entry["title"] for entry in safety.payload["entries"]] == ["Newer game"]


async def test_a_space_with_one_active_member_restores_at_once(
    service: ModuleType, session: AsyncSession
) -> None:
    owner = await _make_user(session, "aloneowner")
    space_id = await space_repo.create_space(session, owner.id)
    other = await _make_user(session, "alonepending")
    await space_repo.add_invited_member(session, space_id, other.id)
    await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=owner.id,
            title="Solo",
            genre="RPG",
            platform="PC",
            status="Not Started",
            owned=True,
            interest=5,
            space_id=space_id,
        ),
    )
    backup = await service.create_manual_backup(session, owner)
    await _wipe_entries(session, space_id)

    response = await service.request_restore(session, owner, backup.id)

    assert response.restored is True
    assert response.result is not None
    assert response.result.entry_count == 1
    assert [
        e.title for e in await backlog_entry_repo.get_backlog_entries_by_space(session, space_id)
    ] == ["Solo"]


async def test_only_one_restore_can_wait_at_a_time(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "single")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await service.request_restore(session, first, backup.id)

    with pytest.raises(ConflictError):
        await service.request_restore(session, second, backup.id)


async def test_either_member_can_withdraw_the_request(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "withdraw")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)

    for withdrawer in (first, second):
        await service.request_restore(session, first, backup.id)
        await service.withdraw_restore_request(session, withdrawer)

        assert (await service.list_backups(session, first)).restore_request is None
        with pytest.raises(NotFoundError):
            await service.approve_restore(session, second)


async def test_an_expired_request_is_gone_and_cannot_be_approved(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "expire")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await service.request_restore(session, first, backup.id)
    await session.execute(
        text(
            'UPDATE "blm-system"."SpaceRestoreRequests" '
            'SET "CreatedAt" = "CreatedAt" - interval \'25 hours\''
        )
    )

    assert (await service.list_backups(session, second)).restore_request is None
    with pytest.raises(NotFoundError):
        await service.approve_restore(session, second)
    again = await service.request_restore(session, second, backup.id)
    assert again.request is not None


async def test_a_member_leaving_takes_the_open_request_with_them(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "leave")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await service.request_restore(session, first, backup.id)

    await space_repo.remove_member(session, space_id, first.id)

    assert (await service.list_backups(session, second)).restore_request is None
    with pytest.raises(NotFoundError):
        await service.approve_restore(session, second)


async def test_a_member_receives_only_their_own_member_data(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "privacy")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)

    exported_backup = await service.export_backup(session, second, backup.id)
    exported_space = await service.export_space(session, second)

    for payload in (exported_backup, exported_space):
        assert [row.review for row in payload.member_data] == ["Too grindy"]
        assert [row.user_id for row in payload.member_data] == [second.id]
        assert [entry.title for entry in payload.entries] == ["Deep Rock Galactic"]


async def test_the_member_data_of_a_member_who_left_is_not_restored(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "gone")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await space_repo.remove_member(session, space_id, second.id)
    await _wipe_entries(session, space_id)

    await service.request_restore(session, first, backup.id)

    assert await _member_reviews(session, space_id) == {first.id: "Great with friends"}


async def test_rename_and_delete_a_backup(service: ModuleType, session: AsyncSession) -> None:
    space_id, first, second = await _make_space(session, "label")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)

    renamed = await service.rename_backup(session, second, backup.id, "  Before the sale  ")
    listed = (await service.list_backups(session, first)).backups
    await service.delete_backup(session, second, backup.id)

    assert renamed.name == "Before the sale"
    assert [item.name for item in listed] == ["Before the sale"]
    assert (await service.list_backups(session, first)).backups == []


async def test_deleting_the_backup_of_an_open_request_ends_the_request(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "cascade")
    await _seed(session, space_id, first, second)
    backup = await service.create_manual_backup(session, first)
    await service.request_restore(session, first, backup.id)

    await service.delete_backup(session, first, backup.id)

    assert (await service.list_backups(session, second)).restore_request is None


async def test_safety_and_automatic_snapshots_skip_an_empty_or_unchanged_space(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "skip")

    assert await service.create_backup(session, space_id, "pre-delete") is None
    await _seed(session, space_id, first, second)
    stored = await service.create_backup(session, space_id, "pre-delete", first.id)
    repeated = await service.create_backup(session, space_id, "pre-delete", first.id)

    assert stored is not None
    assert repeated is None


async def test_the_scheduler_backs_up_every_space_once_per_interval(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "auto")
    await _seed(session, space_id, first, second)
    empty_id, _, _ = await _make_space(session, "autoempty")

    await service.create_due_auto_backups(session)
    await service.create_due_auto_backups(session)

    listed = (await service.list_backups(session, first)).backups
    assert [(item.kind, item.created_by) for item in listed] == [("auto", None)]
    assert await service.space_backup_repo.list_backups(session, empty_id) == []


async def test_retention_keeps_the_newest_per_kind(
    service: ModuleType, session: AsyncSession
) -> None:
    space_id, first, second = await _make_space(session, "retain")
    await _seed(session, space_id, first, second)

    for _ in range(service.RETENTION["manual"] + 3):
        await service.create_manual_backup(session, first)
    await service.create_backup(session, space_id, "pre-delete", first.id)

    kinds = [item.kind for item in (await service.list_backups(session, first)).backups]
    assert kinds.count("manual") == service.RETENTION["manual"]
    assert kinds.count("pre-delete") == 1

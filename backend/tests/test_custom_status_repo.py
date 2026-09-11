import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.repositories import custom_status_repo, user_repo
from backlog_manager_backend.schemas.custom_status import (
    CreateCustomStatusParams,
    UpdateCustomStatusParams,
)
from backlog_manager_backend.schemas.user import CreateUserParams


async def _make_user(session: AsyncSession) -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username="statusowner", email="statusowner@example.com", password_hash="h"),
    )


async def test_create_custom_status(session: AsyncSession) -> None:
    user = await _make_user(session)

    status = await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=user.id, name="Playing in Co-Op")
    )

    assert status.name == "Playing in Co-Op"
    assert status.user_id == user.id


async def test_get_custom_statuses_by_user(session: AsyncSession) -> None:
    user = await _make_user(session)
    await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=user.id, name="Co-Op")
    )
    await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=user.id, name="Replay")
    )

    statuses = await custom_status_repo.get_custom_statuses_by_user(session, user.id)

    assert {s.name for s in statuses} == {"Co-Op", "Replay"}


async def test_get_custom_statuses_isolated_per_user(session: AsyncSession) -> None:
    user_a = await user_repo.create_user(
        session,
        CreateUserParams(username="isoa", email="isoa@example.com", password_hash="h"),
    )
    user_b = await user_repo.create_user(
        session,
        CreateUserParams(username="isob", email="isob@example.com", password_hash="h"),
    )
    await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=user_a.id, name="Co-Op")
    )

    statuses_b = await custom_status_repo.get_custom_statuses_by_user(session, user_b.id)

    assert statuses_b == []


async def test_update_custom_status(session: AsyncSession) -> None:
    user = await _make_user(session)
    status = await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=user.id, name="Co-Op")
    )

    updated = await custom_status_repo.update_custom_status(
        session, UpdateCustomStatusParams(status_id=status.status_id, name="Playing in Co-Op")
    )

    assert updated.name == "Playing in Co-Op"


async def test_update_custom_status_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await custom_status_repo.update_custom_status(
            session, UpdateCustomStatusParams(status_id=999999, name="X")
        )


async def test_delete_custom_status(session: AsyncSession) -> None:
    user = await _make_user(session)
    status = await custom_status_repo.create_custom_status(
        session, CreateCustomStatusParams(user_id=user.id, name="Co-Op")
    )

    deleted = await custom_status_repo.delete_custom_status(session, status.status_id)

    assert deleted.name == "Co-Op"
    assert await custom_status_repo.get_custom_statuses_by_user(session, user.id) == []


async def test_delete_custom_status_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await custom_status_repo.delete_custom_status(session, 999999)
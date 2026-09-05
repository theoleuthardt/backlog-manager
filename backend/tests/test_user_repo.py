import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, NotFoundError
from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.user import CreateUserParams, UpdateUserParams


async def _make_user(session: AsyncSession, **overrides: object) -> object:
    params = CreateUserParams(
        username=overrides.get("username", "testuser"),
        email=overrides.get("email", "testuser@example.com"),
        password_hash=overrides.get("password_hash", "hashed-password"),
        steam_id=overrides.get("steam_id"),
    )
    return await user_repo.create_user(session, params)


async def test_create_user(session: AsyncSession) -> None:
    user = await _make_user(session)

    assert user.id is not None
    assert user.name == "testuser"
    assert user.email == "testuser@example.com"
    assert user.created_at is not None
    assert user.updated_at is not None


async def test_create_user_duplicate_email_conflicts(session: AsyncSession) -> None:
    await _make_user(session, username="first", email="dupe@example.com")

    with pytest.raises(ConflictError):
        await _make_user(session, username="second", email="dupe@example.com")


async def test_get_user_by_id(session: AsyncSession) -> None:
    created = await _make_user(session)

    fetched = await user_repo.get_user_by_id(session, created.id)

    assert fetched.id == created.id
    assert fetched.email == created.email


async def test_get_user_by_id_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await user_repo.get_user_by_id(session, 999_999_999)


async def test_get_user_by_username(session: AsyncSession) -> None:
    created = await _make_user(session, username="findme", email="findme@example.com")

    fetched = await user_repo.get_user_by_username(session, "findme")

    assert fetched is not None
    assert fetched.id == created.id


async def test_get_user_by_username_returns_none_when_missing(
    session: AsyncSession,
) -> None:
    assert await user_repo.get_user_by_username(session, "nobody") is None


async def test_get_user_by_email(session: AsyncSession) -> None:
    created = await _make_user(session, email="uniqueemail@example.com")

    fetched = await user_repo.get_user_by_email(session, "uniqueemail@example.com")

    assert fetched is not None
    assert fetched.id == created.id


async def test_get_all_users(session: AsyncSession) -> None:
    await _make_user(session, username="alluser1", email="alluser1@example.com")
    await _make_user(session, username="alluser2", email="alluser2@example.com")

    users = await user_repo.get_all_users(session)

    usernames = {u.name for u in users}
    assert {"alluser1", "alluser2"} <= usernames


async def test_update_user_partial(session: AsyncSession) -> None:
    created = await _make_user(session, username="original", email="original@example.com")

    updated = await user_repo.update_user(
        session, UpdateUserParams(user_id=created.id, username="renamed")
    )

    assert updated.name == "renamed"
    assert updated.email == "original@example.com"  # unchanged fields stay untouched


async def test_update_user_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await user_repo.update_user(
            session, UpdateUserParams(user_id=999_999_999, username="ghost")
        )


async def test_delete_user(session: AsyncSession) -> None:
    created = await _make_user(session)

    deleted = await user_repo.delete_user(session, created.id)

    assert deleted.id == created.id
    with pytest.raises(NotFoundError):
        await user_repo.get_user_by_id(session, created.id)


async def test_delete_user_not_found(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await user_repo.delete_user(session, 999_999_999)

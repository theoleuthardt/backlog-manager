from types import ModuleType

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.user import CreateUserParams


@pytest.fixture
def auth_service() -> ModuleType:
    """Imported lazily - see test_game_service.py's game_service fixture
    for why (services.auth_service -> auth.tokens -> config eagerly
    builds Settings() on import)."""
    from backlog_manager_backend.services import auth_service as module

    return module


async def test_create_user_creates_user_with_hashed_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    user = await auth_service.create_user(
        session,
        CreateUserRequest(username="newuser", email="newuser@example.com", password="hunter22"),
    )

    assert user.name == "newuser"
    assert user.email == "newuser@example.com"
    assert user.is_admin is False
    assert user.password_hash != "hunter22"


async def test_create_user_can_create_an_admin(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    user = await auth_service.create_user(
        session,
        CreateUserRequest(
            username="newadmin", email="newadmin@example.com", password="hunter22", is_admin=True
        ),
    )

    assert user.is_admin is True


async def test_create_user_rejects_duplicate_email(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    await auth_service.create_user(
        session,
        CreateUserRequest(username="first", email="dupe@example.com", password="hunter22"),
    )

    with pytest.raises(ConflictError):
        await auth_service.create_user(
            session,
            CreateUserRequest(username="second", email="dupe@example.com", password="hunter22"),
        )


async def test_create_user_rejects_short_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    with pytest.raises(ValidationError):
        await auth_service.create_user(
            session,
            CreateUserRequest(username="shortpw", email="shortpw@example.com", password="short"),
        )


async def test_login_returns_token_for_correct_credentials(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import decode_access_token
    from backlog_manager_backend.schemas.auth import LoginParams
    from backlog_manager_backend.schemas.user import CreateUserRequest

    user = await auth_service.create_user(
        session,
        CreateUserRequest(username="loginuser", email="loginuser@example.com", password="hunter22"),
    )

    token = await auth_service.login(
        session, LoginParams(email="loginuser@example.com", password="hunter22")
    )

    assert decode_access_token(token) == user.id


async def test_login_rejects_wrong_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams
    from backlog_manager_backend.schemas.user import CreateUserRequest

    await auth_service.create_user(
        session,
        CreateUserRequest(username="wrongpw", email="wrongpw@example.com", password="hunter22"),
    )

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="wrongpw@example.com", password="not-hunter22")
        )


async def test_login_rejects_unknown_email(auth_service: ModuleType, session: AsyncSession) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="nobody@example.com", password="hunter22")
        )


async def test_login_rejects_oauth_only_account_with_empty_password_hash(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams

    await user_repo.create_user(
        session,
        CreateUserParams(username="oauthuser", email="oauthuser@example.com", password_hash=""),
    )

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="oauthuser@example.com", password="anything")
        )


async def test_login_verifies_a_password_hash_even_for_unknown_email(
    auth_service: ModuleType, session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Regression test for a timing side-channel: skipping Argon2
    verification for an unknown email would make that path measurably
    faster than a wrong-password attempt against a real account,
    letting an attacker enumerate registered emails by response time.
    Asserts the structural fix (verify_password always runs against
    some hash) rather than measuring wall-clock time, which would be
    flaky in CI."""
    from backlog_manager_backend.schemas.auth import LoginParams

    calls: list[str] = []
    monkeypatch.setattr(
        auth_service,
        "verify_password",
        lambda password_hash, password: calls.append(password_hash) or False,
    )

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="nobody@example.com", password="anything")
        )

    assert calls == [auth_service._DUMMY_PASSWORD_HASH]

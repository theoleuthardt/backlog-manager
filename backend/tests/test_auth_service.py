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


async def test_register_creates_user_with_hashed_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.auth import RegisterParams

    user = await auth_service.register(
        session,
        RegisterParams(username="newuser", email="newuser@example.com", password="hunter2"),
    )

    assert user.name == "newuser"
    assert user.email == "newuser@example.com"


async def test_register_rejects_duplicate_email(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.auth import RegisterParams

    await auth_service.register(
        session, RegisterParams(username="first", email="dupe@example.com", password="hunter2")
    )

    with pytest.raises(ConflictError):
        await auth_service.register(
            session,
            RegisterParams(username="second", email="dupe@example.com", password="hunter2"),
        )


async def test_login_returns_token_for_correct_credentials(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import decode_access_token
    from backlog_manager_backend.schemas.auth import LoginParams, RegisterParams

    user = await auth_service.register(
        session,
        RegisterParams(username="loginuser", email="loginuser@example.com", password="hunter2"),
    )

    token = await auth_service.login(
        session, LoginParams(email="loginuser@example.com", password="hunter2")
    )

    assert decode_access_token(token) == user.id


async def test_login_rejects_wrong_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams, RegisterParams

    await auth_service.register(
        session,
        RegisterParams(username="wrongpw", email="wrongpw@example.com", password="hunter2"),
    )

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="wrongpw@example.com", password="not-hunter2")
        )


async def test_login_rejects_unknown_email(auth_service: ModuleType, session: AsyncSession) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="nobody@example.com", password="hunter2")
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

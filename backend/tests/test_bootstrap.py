from datetime import UTC, datetime
from types import ModuleType

import pytest

from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.schemas.user import CreateUserRequest, UpdateUserParams, User


@pytest.fixture
def bootstrap() -> ModuleType:
    """Imported lazily - see test_game_service.py's game_service fixture
    for why (bootstrap -> config eagerly builds Settings() on import).
    Tested as a pure unit against monkeypatched collaborators rather
    than a real DB: the "no admin exists yet" precondition can't be
    reliably reproduced against the shared test-session Postgres
    container, which other tests continuously populate with real,
    permanently-committed users (some of them admins) via
    create_and_login."""
    from backlog_manager_backend import bootstrap as module

    return module


def _fake_user(email: str, is_admin: bool, user_id: int = 1) -> User:
    now = datetime.now(UTC).replace(tzinfo=None)
    return User(
        id=user_id,
        name=email.split("@")[0],
        email=email,
        created_at=now,
        updated_at=now,
        is_admin=is_admin,
    )


async def test_bootstrap_does_nothing_without_env_vars(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", None)
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", None)

    async def fail_if_called(*args: object, **kwargs: object) -> None:
        raise AssertionError("should not query the DB when env vars are unset")

    monkeypatch.setattr(bootstrap, "get_all_users", fail_if_called)

    await bootstrap.bootstrap_initial_admin()


async def test_bootstrap_creates_admin_when_no_users_exist(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", "bootstrap-admin@example.com")
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", "hunter22")

    async def no_users(session: object) -> list[User]:
        return []

    async def no_matching_user(session: object, email: str) -> None:
        return None

    created_with: list[CreateUserRequest] = []

    async def fake_create_user(session: object, params: CreateUserRequest) -> User:
        created_with.append(params)
        return _fake_user(params.email, params.is_admin)

    monkeypatch.setattr(bootstrap, "get_all_users", no_users)
    monkeypatch.setattr(bootstrap, "get_user_by_email", no_matching_user)
    monkeypatch.setattr(bootstrap, "create_user", fake_create_user)

    await bootstrap.bootstrap_initial_admin()

    assert len(created_with) == 1
    assert created_with[0].email == "bootstrap-admin@example.com"
    assert created_with[0].password == "hunter22"
    assert created_with[0].is_admin is True


async def test_bootstrap_is_a_noop_when_an_admin_already_exists(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", "bootstrap-admin2@example.com")
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", "hunter22")

    async def one_admin(session: object) -> list[User]:
        return [_fake_user("someadmin@example.com", True)]

    async def fail_if_called(*args: object, **kwargs: object) -> None:
        raise AssertionError("should not touch the DB further once an admin exists")

    monkeypatch.setattr(bootstrap, "get_all_users", one_admin)
    monkeypatch.setattr(bootstrap, "get_user_by_email", fail_if_called)
    monkeypatch.setattr(bootstrap, "create_user", fail_if_called)
    monkeypatch.setattr(bootstrap, "update_user", fail_if_called)

    await bootstrap.bootstrap_initial_admin()


async def test_bootstrap_promotes_existing_user_with_matching_email(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """No admin exists, but a user with the target email already does
    (e.g. a pre-migration account with no admin flag set) - promote
    that user instead of trying to create a duplicate."""
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", "regular@example.com")
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", "hunter22")

    existing = _fake_user("regular@example.com", is_admin=False, user_id=42)

    async def no_admins(session: object) -> list[User]:
        return [existing]

    async def matching_user(session: object, email: str) -> User:
        assert email == "regular@example.com"
        return existing

    promoted_with: list[UpdateUserParams] = []

    async def fake_update_user(session: object, params: UpdateUserParams) -> User:
        promoted_with.append(params)
        return _fake_user(existing.email, True, user_id=existing.id)

    async def fail_if_called(*args: object, **kwargs: object) -> None:
        raise AssertionError("should promote, not create a new user")

    monkeypatch.setattr(bootstrap, "get_all_users", no_admins)
    monkeypatch.setattr(bootstrap, "get_user_by_email", matching_user)
    monkeypatch.setattr(bootstrap, "update_user", fake_update_user)
    monkeypatch.setattr(bootstrap, "create_user", fail_if_called)

    await bootstrap.bootstrap_initial_admin()

    assert len(promoted_with) == 1
    assert promoted_with[0].user_id == 42
    assert promoted_with[0].is_admin is True


async def test_bootstrap_creates_new_admin_when_other_users_exist(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """No admin exists, other (non-matching-email) users do - creates a
    fresh admin rather than mistaking "any users" for "an admin"."""
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", "newadmin@example.com")
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", "hunter22")

    async def no_admins(session: object) -> list[User]:
        return [_fake_user("someoneelse@example.com", False)]

    async def no_matching_user(session: object, email: str) -> None:
        return None

    created_with: list[CreateUserRequest] = []

    async def fake_create_user(session: object, params: CreateUserRequest) -> User:
        created_with.append(params)
        return _fake_user(params.email, params.is_admin)

    monkeypatch.setattr(bootstrap, "get_all_users", no_admins)
    monkeypatch.setattr(bootstrap, "get_user_by_email", no_matching_user)
    monkeypatch.setattr(bootstrap, "create_user", fake_create_user)

    await bootstrap.bootstrap_initial_admin()

    assert len(created_with) == 1
    assert created_with[0].email == "newadmin@example.com"


async def test_bootstrap_lets_validation_error_fail_startup(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A misconfigured bootstrap password (e.g. too short) must fail
    startup loudly, not leave the deployment with no admin and no way
    to create one."""
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", "bad@example.com")
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", "short")

    async def no_admins(session: object) -> list[User]:
        return []

    async def no_matching_user(session: object, email: str) -> None:
        return None

    async def raise_validation_error(session: object, params: CreateUserRequest) -> User:
        raise ValidationError("Password must be at least 8 characters long")

    monkeypatch.setattr(bootstrap, "get_all_users", no_admins)
    monkeypatch.setattr(bootstrap, "get_user_by_email", no_matching_user)
    monkeypatch.setattr(bootstrap, "create_user", raise_validation_error)

    with pytest.raises(ValidationError):
        await bootstrap.bootstrap_initial_admin()


async def test_bootstrap_swallows_conflict_error(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A ConflictError (e.g. a concurrent bootstrap race) is expected
    and non-fatal - an admin exists either way."""
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", "race@example.com")
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", "hunter22")

    async def no_admins(session: object) -> list[User]:
        return []

    async def no_matching_user(session: object, email: str) -> None:
        return None

    async def raise_conflict_error(session: object, params: CreateUserRequest) -> User:
        raise ConflictError("A resource with this identifier already exists")

    monkeypatch.setattr(bootstrap, "get_all_users", no_admins)
    monkeypatch.setattr(bootstrap, "get_user_by_email", no_matching_user)
    monkeypatch.setattr(bootstrap, "create_user", raise_conflict_error)

    await bootstrap.bootstrap_initial_admin()

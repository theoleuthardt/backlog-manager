from datetime import UTC, datetime
from types import ModuleType

import pytest

from backlog_manager_backend.schemas.user import CreateUserRequest, User


@pytest.fixture
def bootstrap() -> ModuleType:
    """Imported lazily - see test_game_service.py's game_service fixture
    for why (bootstrap -> config eagerly builds Settings() on import).
    Tested as a pure unit against monkeypatched collaborators rather
    than a real DB: the "no users exist yet" precondition can't be
    reliably reproduced against the shared test-session Postgres
    container, which other tests continuously populate with real,
    permanently-committed users via create_and_login."""
    from backlog_manager_backend import bootstrap as module

    return module


def _fake_user(email: str, is_admin: bool) -> User:
    now = datetime.now(UTC).replace(tzinfo=None)
    return User(
        id=1,
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

    created_with: list[CreateUserRequest] = []

    async def fake_create_user(session: object, params: CreateUserRequest) -> User:
        created_with.append(params)
        return _fake_user(params.email, params.is_admin)

    monkeypatch.setattr(bootstrap, "get_all_users", no_users)
    monkeypatch.setattr(bootstrap, "create_user", fake_create_user)

    await bootstrap.bootstrap_initial_admin()

    assert len(created_with) == 1
    assert created_with[0].email == "bootstrap-admin@example.com"
    assert created_with[0].password == "hunter22"
    assert created_with[0].is_admin is True


async def test_bootstrap_is_a_noop_when_a_user_already_exists(
    bootstrap: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(bootstrap.settings, "initial_admin_email", "bootstrap-admin2@example.com")
    monkeypatch.setattr(bootstrap.settings, "initial_admin_password", "hunter22")

    async def one_existing_user(session: object) -> list[User]:
        return [_fake_user("someone@example.com", False)]

    async def fail_if_called(session: object, params: CreateUserRequest) -> User:
        raise AssertionError("should not create a user when one already exists")

    monkeypatch.setattr(bootstrap, "get_all_users", one_existing_user)
    monkeypatch.setattr(bootstrap, "create_user", fail_if_called)

    await bootstrap.bootstrap_initial_admin()

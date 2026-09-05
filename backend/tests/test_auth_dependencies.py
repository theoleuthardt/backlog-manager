from types import ModuleType

import pytest
from litestar.exceptions import NotAuthorizedException
from litestar.testing import RequestFactory
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.user import CreateUserParams


@pytest.fixture
def dependencies() -> ModuleType:
    """Imported lazily - see test_game_service.py's game_service fixture
    for why (auth.dependencies -> auth.tokens -> config eagerly builds
    Settings() on import)."""
    from backlog_manager_backend.auth import dependencies as module

    return module


async def _make_user(session: AsyncSession) -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username="depsuser", email="depsuser@example.com", password_hash="h"),
    )


async def test_get_current_user_returns_user_for_valid_token(
    dependencies: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import create_access_token

    user = await _make_user(session)
    token = create_access_token(user.id)
    request = RequestFactory().get(headers={"Authorization": f"Bearer {token}"})

    current_user = await dependencies.get_current_user(request, session)

    assert current_user.id == user.id


async def test_get_current_user_rejects_missing_header(
    dependencies: ModuleType, session: AsyncSession
) -> None:
    request = RequestFactory().get()

    with pytest.raises(NotAuthorizedException):
        await dependencies.get_current_user(request, session)


async def test_get_current_user_rejects_non_bearer_header(
    dependencies: ModuleType, session: AsyncSession
) -> None:
    request = RequestFactory().get(headers={"Authorization": "Basic somevalue"})

    with pytest.raises(NotAuthorizedException):
        await dependencies.get_current_user(request, session)


async def test_get_current_user_rejects_invalid_token(
    dependencies: ModuleType, session: AsyncSession
) -> None:
    request = RequestFactory().get(headers={"Authorization": "Bearer not-a-real-token"})

    with pytest.raises(NotAuthorizedException):
        await dependencies.get_current_user(request, session)


async def test_get_current_user_rejects_token_for_deleted_user(
    dependencies: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import create_access_token

    user = await _make_user(session)
    token = create_access_token(user.id)
    await user_repo.delete_user(session, user.id)
    request = RequestFactory().get(headers={"Authorization": f"Bearer {token}"})

    with pytest.raises(NotAuthorizedException):
        await dependencies.get_current_user(request, session)

from litestar import Router, delete, get, post, put
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotFoundException
from litestar.params import FromPath
from litestar.status_codes import HTTP_201_CREATED, HTTP_204_NO_CONTENT, HTTP_409_CONFLICT
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import get_current_user, require_admin
from backlog_manager_backend.auth.passwords import hash_password
from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError
from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.user import (
    CreateUserRequest,
    PublicUser,
    UpdateOwnUserRequest,
    UpdateUserAdminRequest,
    UpdateUserParams,
    User,
)
from backlog_manager_backend.services.auth_service import create_user, validate_password_strength

_USER_NOT_FOUND = "User not found"

# Every handler below /api/admin/* takes an unused `current_user:
# NamedDependency[User]` parameter deliberately - Litestar only resolves
# (and therefore only runs) a router-level dependency for handlers that
# actually declare it as a parameter. Without it, require_admin below is
# registered but never called, and the route is silently unprotected.
# Do not remove it even though nothing in the body reads it.


def _hash_if_present(password: str | object) -> str | object:
    return hash_password(password) if isinstance(password, str) else password


@get("/api/user/me")
async def get_own_user(current_user: NamedDependency[User]) -> PublicUser:
    return PublicUser.from_user(current_user)


@put("/api/user/me")
async def update_own_user(
    data: UpdateOwnUserRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> PublicUser:
    try:
        if isinstance(data.password, str):
            validate_password_strength(data.password)

        updated = await user_repo.update_user(
            db_session,
            UpdateUserParams(
                user_id=current_user.id,
                username=data.username,
                email=data.email,
                password_hash=_hash_if_present(data.password),
                steam_id=data.steam_id,
            ),
        )
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    return PublicUser.from_user(updated)


@delete("/api/user/me", status_code=HTTP_204_NO_CONTENT)
async def delete_own_user(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    await user_repo.delete_user(db_session, current_user.id)


@get("/api/user/by-username/{username:str}")
async def get_user_by_username(
    username: FromPath[str],
    db_session: NamedDependency[AsyncSession],
) -> PublicUser:
    user = await user_repo.get_user_by_username(db_session, username)
    if user is None:
        raise NotFoundException(_USER_NOT_FOUND)
    return PublicUser.from_user(user)


@post("/api/admin/users", status_code=HTTP_201_CREATED)
async def create_user_admin(
    data: CreateUserRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> PublicUser:
    try:
        created = await create_user(db_session, data)
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    return PublicUser.from_user(created)


@get("/api/admin/users")
async def list_all_users(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> list[PublicUser]:
    users = await user_repo.get_all_users(db_session)
    return [PublicUser.from_user(user) for user in users]


@get("/api/admin/users/{user_id:int}")
async def get_user_by_id_admin(
    user_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> PublicUser:
    try:
        user = await user_repo.get_user_by_id(db_session, user_id)
    except NotFoundError as error:
        raise NotFoundException(_USER_NOT_FOUND) from error
    return PublicUser.from_user(user)


@put("/api/admin/users/{user_id:int}")
async def update_user_admin(
    user_id: FromPath[int],
    data: UpdateUserAdminRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> PublicUser:
    try:
        if isinstance(data.password, str):
            validate_password_strength(data.password)

        updated = await user_repo.update_user(
            db_session,
            UpdateUserParams(
                user_id=user_id,
                username=data.username,
                email=data.email,
                password_hash=_hash_if_present(data.password),
                steam_id=data.steam_id,
                is_admin=data.is_admin,
            ),
        )
    except NotFoundError as error:
        raise NotFoundException(_USER_NOT_FOUND) from error
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    return PublicUser.from_user(updated)


@delete("/api/admin/users/{user_id:int}", status_code=HTTP_204_NO_CONTENT)
async def delete_user_admin(
    user_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    try:
        await user_repo.delete_user(db_session, user_id)
    except NotFoundError as error:
        raise NotFoundException(_USER_NOT_FOUND) from error


user_router = Router(
    path="",
    route_handlers=[get_own_user, update_own_user, delete_own_user, get_user_by_username],
    dependencies={"current_user": Provide(get_current_user)},
)

admin_user_router = Router(
    path="",
    route_handlers=[
        create_user_admin,
        list_all_users,
        get_user_by_id_admin,
        update_user_admin,
        delete_user_admin,
    ],
    dependencies={
        "authenticated_user": Provide(get_current_user),
        "current_user": Provide(require_admin),
    },
)

import msgspec
from litestar import Router, delete, get, post, put
from litestar.datastructures import CacheControlHeader
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotFoundException, ServiceUnavailableException
from litestar.params import FromPath
from litestar.status_codes import HTTP_201_CREATED, HTTP_204_NO_CONTENT, HTTP_409_CONFLICT
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import (
    BEARER_SECURITY_REQUIREMENT,
    get_current_user,
    require_admin,
)
from backlog_manager_backend.auth.encryption import encrypt
from backlog_manager_backend.auth.passwords import hash_password
from backlog_manager_backend.config import settings
from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError
from backlog_manager_backend.integrations.types import IGDBCredentials
from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.user import (
    CreateUserRequest,
    PublicUser,
    PublicUsername,
    UpdateOwnUserRequest,
    UpdateUserAdminRequest,
    UpdateUserParams,
    User,
)
from backlog_manager_backend.services.auth_service import create_user, validate_password_strength

# Every response below includes email and/or is_admin - a private cache
# (browser) must not reuse one of these for a different user after e.g. an
# account switch on a shared machine.
_NO_STORE = CacheControlHeader(no_store=True)

_USER_NOT_FOUND = "User not found"

# Every handler below /api/admin/* takes an unused `current_user:
# NamedDependency[User]` parameter deliberately - Litestar only resolves
# (and therefore only runs) a router-level dependency for handlers that
# actually declare it as a parameter. Without it, require_admin below is
# registered but never called, and the route is silently unprotected.
# Do not remove it even though nothing in the body reads it.


def _hash_if_present(password: str | object) -> str | object:
    return hash_password(password) if isinstance(password, str) else password


def _encrypt_steam_api_key_if_present(steam_api_key: str | None | object) -> str | None | object:
    if not isinstance(steam_api_key, str):
        return steam_api_key
    trimmed = steam_api_key.strip()
    if not trimmed:
        return None
    if not settings.steam_api_key_encryption_key:
        raise ServiceUnavailableException("Steam API key storage is not configured")
    try:
        return encrypt(trimmed, settings.steam_api_key_encryption_key)
    except ValueError as error:
        raise ServiceUnavailableException("Steam API key storage is not configured") from error


_IGDB_CREDENTIALS_NOT_CONFIGURED = "IGDB credential storage is not configured"
_IGDB_CREDENTIALS_INCOMPLETE = "Both IGDB Client ID and Client Secret must be set together"


def _encrypt_igdb_credentials_if_present(
    client_id: str | None | object, client_secret: str | None | object
) -> str | None | object:
    """client_id and client_secret are encrypted together as one JSON
    blob (IGDBCredentials) rather than as two independent columns, so
    the database can never hold a client_id without its secret or vice
    versa - reuses the same Fernet key as
    _encrypt_steam_api_key_if_present, since it's just a shared secret
    for encrypting arbitrary per-user values at rest. UNSET on both
    (neither field sent) means "leave unchanged"; both blank means
    "clear"; exactly one blank, or exactly one UNSET while the other
    is sent, is rejected rather than silently dropping (or clearing)
    the other half of an existing pair."""
    if client_id is msgspec.UNSET and client_secret is msgspec.UNSET:
        return msgspec.UNSET
    if client_id is msgspec.UNSET or client_secret is msgspec.UNSET:
        raise ClientException(_IGDB_CREDENTIALS_INCOMPLETE)
    normalized_client_id = client_id.strip() if isinstance(client_id, str) else None
    normalized_client_secret = client_secret.strip() if isinstance(client_secret, str) else None
    if not normalized_client_id and not normalized_client_secret:
        return None
    if not normalized_client_id or not normalized_client_secret:
        raise ClientException(_IGDB_CREDENTIALS_INCOMPLETE)
    if not settings.steam_api_key_encryption_key:
        raise ServiceUnavailableException(_IGDB_CREDENTIALS_NOT_CONFIGURED)
    payload = msgspec.json.encode(
        IGDBCredentials(client_id=normalized_client_id, client_secret=normalized_client_secret)
    ).decode()
    try:
        return encrypt(payload, settings.steam_api_key_encryption_key)
    except ValueError as error:
        raise ServiceUnavailableException(_IGDB_CREDENTIALS_NOT_CONFIGURED) from error


@get("/api/user/me", security=BEARER_SECURITY_REQUIREMENT)
async def get_own_user(current_user: NamedDependency[User]) -> PublicUser:
    return PublicUser.from_user(current_user)


@put("/api/user/me", security=BEARER_SECURITY_REQUIREMENT)
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
                steam_api_key_encrypted=_encrypt_steam_api_key_if_present(data.steam_api_key),
                igdb_credentials_encrypted=_encrypt_igdb_credentials_if_present(
                    data.igdb_client_id, data.igdb_client_secret
                ),
                steam_auto_import_enabled=data.steam_auto_import_enabled,
            ),
        )
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    return PublicUser.from_user(updated)


@delete("/api/user/me", status_code=HTTP_204_NO_CONTENT, security=BEARER_SECURITY_REQUIREMENT)
async def delete_own_user(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    try:
        await user_repo.delete_user(db_session, current_user.id)
    except ValidationError as error:
        raise ClientException(str(error)) from error


@get("/api/user/by-username/{username:str}")
async def get_user_by_username(
    username: FromPath[str],
    db_session: NamedDependency[AsyncSession],
) -> PublicUsername:
    user = await user_repo.get_user_by_username(db_session, username)
    if user is None:
        raise NotFoundException(_USER_NOT_FOUND)
    return PublicUsername.from_user(user)


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
                steam_api_key_encrypted=_encrypt_steam_api_key_if_present(data.steam_api_key),
                igdb_credentials_encrypted=_encrypt_igdb_credentials_if_present(
                    data.igdb_client_id, data.igdb_client_secret
                ),
                steam_auto_import_enabled=data.steam_auto_import_enabled,
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
    except ValidationError as error:
        raise ClientException(str(error)) from error


user_router = Router(
    path="",
    route_handlers=[get_own_user, update_own_user, delete_own_user, get_user_by_username],
    dependencies={"current_user": Provide(get_current_user)},
    cache_control=_NO_STORE,
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
    cache_control=_NO_STORE,
    security=BEARER_SECURITY_REQUIREMENT,
)

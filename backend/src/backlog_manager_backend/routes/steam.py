import httpx
from litestar import Router, post
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, ServiceUnavailableException
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.auth.encryption import decrypt
from backlog_manager_backend.config import settings
from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.schemas.backlog_entry import BacklogEntryResponse
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import steam_service

_STEAM_NOT_CONFIGURED = "Steam Web API integration is not configured"
_STEAM_UNAVAILABLE = "Steam Web API is currently unreachable"


def _resolve_api_key(user: User) -> str:
    if user.steam_api_key_encrypted and settings.steam_api_key_encryption_key:
        return decrypt(user.steam_api_key_encrypted, settings.steam_api_key_encryption_key)
    if settings.steam_web_api_key:
        return settings.steam_web_api_key
    raise ServiceUnavailableException(_STEAM_NOT_CONFIGURED)


@post("/api/user/steam/sync", status_code=200)
async def sync_steam_playtimes(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> list[BacklogEntryResponse]:
    api_key = _resolve_api_key(current_user)

    try:
        updated = await steam_service.sync_playtimes(db_session, current_user, api_key)
    except ValidationError as error:
        raise ClientException(str(error)) from error
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_STEAM_UNAVAILABLE) from error

    return [BacklogEntryResponse.from_entry(entry) for entry in updated]


steam_router = Router(
    path="",
    route_handlers=[sync_steam_playtimes],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
)

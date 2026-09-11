from collections.abc import Awaitable
from typing import Annotated

import httpx
import msgspec
from cryptography.fernet import InvalidToken
from litestar import Router, get
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ServiceUnavailableException
from litestar.params import FromPath, FromQuery, QueryParameter
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.auth.encryption import decrypt
from backlog_manager_backend.config import settings
from backlog_manager_backend.integrations.igdb import (
    get_cover_on_igdb,
    get_game_on_igdb,
    get_game_time_to_beat_on_igdb,
    get_genre_on_igdb,
    get_platform_on_igdb,
    search_game_on_igdb,
)
from backlog_manager_backend.integrations.types import (
    EnrichedResult,
    IGDBCover,
    IGDBCredentials,
    IGDBGameData,
    IGDBGameTimeToBeat,
    IGDBGenre,
    IGDBPlatform,
    IGDBSearchResult,
    KeyShopOffer,
)
from backlog_manager_backend.schemas.game_price import GamePrice
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import game_service, key_shop_price_service, price_service

_IGDB_NOT_CONFIGURED = "IGDB integration is not configured"
_IGDB_UNAVAILABLE = "IGDB is currently unreachable"
_STEAMGRIDDB_NOT_CONFIGURED = "SteamGridDB integration is not configured"
_STEAMGRIDDB_UNAVAILABLE = "SteamGridDB is currently unreachable"
_CHEAPSHARK_UNAVAILABLE = "CheapShark is currently unreachable"


def _resolve_igdb_credentials(user: User) -> tuple[str, str]:
    """Per-user-credentials-with-global-fallback: a user's own stored
    IGDB client_id/client_secret take priority over the server's
    IGDB_CLIENT_ID/IGDB_CLIENT_SECRET env vars, which remain the
    fallback for users who haven't set their own. Unlike SteamGridDB's
    single API key, IGDB needs both halves of a Twitch OAuth2
    client-credentials pair together - see
    routes/user.py::_encrypt_igdb_credentials_if_present for why
    they're stored as one encrypted blob rather than two columns."""
    if user.igdb_credentials_encrypted and settings.steam_api_key_encryption_key:
        try:
            decrypted = decrypt(
                user.igdb_credentials_encrypted, settings.steam_api_key_encryption_key
            )
            credentials = msgspec.json.decode(decrypted, type=IGDBCredentials)
        except (InvalidToken, ValueError, msgspec.DecodeError) as error:
            raise ServiceUnavailableException(_IGDB_UNAVAILABLE) from error
        return credentials.client_id, credentials.client_secret
    if settings.igdb_client_id and settings.igdb_client_secret:
        return settings.igdb_client_id, settings.igdb_client_secret
    raise ServiceUnavailableException(_IGDB_NOT_CONFIGURED)


def _resolve_steamgriddb_api_key(user: User) -> str | None:
    """Per-user-key-with-global-fallback, mirroring
    routes/steam.py::_resolve_api_key - except a missing key here
    resolves to None rather than raising, since callers (game_service)
    already treat "no key" as a legitimate, non-fatal state (skip
    SteamGridDB, don't fail the whole search)."""
    if user.steamgriddb_api_key_encrypted and settings.steam_api_key_encryption_key:
        try:
            return decrypt(user.steamgriddb_api_key_encrypted, settings.steam_api_key_encryption_key)
        except (InvalidToken, ValueError) as error:
            raise ServiceUnavailableException(_STEAMGRIDDB_UNAVAILABLE) from error
    return settings.steamgriddb_api_key


async def _igdb_credentials(user: User) -> tuple[str, str]:
    """An httpx.HTTPError here is the same class of failure as
    _call_igdb below, just one step earlier (acquiring the token
    itself, before any data query runs)."""
    client_id, client_secret = _resolve_igdb_credentials(user)
    try:
        access_token = await game_service.get_valid_token(client_id, client_secret)
    except RuntimeError as error:
        raise ServiceUnavailableException(_IGDB_NOT_CONFIGURED) from error
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_IGDB_UNAVAILABLE) from error
    return client_id, access_token


async def _call_igdb[T](coro: Awaitable[T]) -> T:
    """search_game_on_igdb() et al. already turn a bad HTTP status from
    IGDB into an empty list internally, but a transport failure
    (timeout, connection refused, ...) still propagates as
    httpx.RequestError - map that to 503 instead of letting it fall
    through to Litestar's generic 500."""
    try:
        return await coro
    except httpx.RequestError as error:
        raise ServiceUnavailableException(_IGDB_UNAVAILABLE) from error


@get("/api/games/search")
async def search_game(
    search_term: FromQuery[str], current_user: NamedDependency[User]
) -> list[IGDBSearchResult]:
    client_id, access_token = await _igdb_credentials(current_user)
    return await _call_igdb(search_game_on_igdb(search_term, client_id, access_token))


@get("/api/games/enriched-search")
async def enriched_search(
    search_term: FromQuery[str], current_user: NamedDependency[User]
) -> list[EnrichedResult]:
    client_id, client_secret = _resolve_igdb_credentials(current_user)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)
    try:
        return await _call_igdb(
            game_service.search(search_term, client_id, client_secret, steamgriddb_api_key)
        )
    except RuntimeError as error:
        raise ServiceUnavailableException(_IGDB_NOT_CONFIGURED) from error


@get("/api/games/steam-app-id")
async def get_steam_app_id(title: FromQuery[str]) -> int | None:
    return await game_service.find_steam_app_id(title)


@get("/api/games/steamgriddb-covers")
async def get_steamgriddb_covers(
    steam_app_id: FromQuery[int], current_user: NamedDependency[User]
) -> list[str]:
    try:
        return await game_service.get_game_covers(
            steam_app_id, _resolve_steamgriddb_api_key(current_user)
        )
    except RuntimeError as error:
        raise ServiceUnavailableException(_STEAMGRIDDB_NOT_CONFIGURED) from error
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_STEAMGRIDDB_UNAVAILABLE) from error


@get("/api/games/{game_id:int}")
async def get_game(
    game_id: FromPath[int], current_user: NamedDependency[User]
) -> list[IGDBGameData]:
    client_id, access_token = await _igdb_credentials(current_user)
    return await _call_igdb(get_game_on_igdb(str(game_id), client_id, access_token))


@get("/api/games/{game_id:int}/time-to-beat")
async def get_game_time_to_beat(
    game_id: FromPath[int], current_user: NamedDependency[User]
) -> list[IGDBGameTimeToBeat]:
    client_id, access_token = await _igdb_credentials(current_user)
    return await _call_igdb(get_game_time_to_beat_on_igdb(game_id, client_id, access_token))


@get("/api/games/platforms/{platform_id:int}")
async def get_platform(
    platform_id: FromPath[int], current_user: NamedDependency[User]
) -> list[IGDBPlatform]:
    client_id, access_token = await _igdb_credentials(current_user)
    return await _call_igdb(get_platform_on_igdb(platform_id, client_id, access_token))


@get("/api/games/covers/{cover_id:int}")
async def get_cover(
    cover_id: FromPath[int], current_user: NamedDependency[User]
) -> list[IGDBCover]:
    client_id, access_token = await _igdb_credentials(current_user)
    return await _call_igdb(get_cover_on_igdb(cover_id, client_id, access_token))


@get("/api/games/genres/{genre_id:int}")
async def get_genre(
    genre_id: FromPath[int], current_user: NamedDependency[User]
) -> list[IGDBGenre]:
    client_id, access_token = await _igdb_credentials(current_user)
    return await _call_igdb(get_genre_on_igdb(genre_id, client_id, access_token))


@get("/api/games/{steam_app_id:int}/price")
async def get_game_price(
    steam_app_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> GamePrice:
    """current_user is unused (price data isn't user-specific) but must
    stay declared - see authenticated_games_router's dependencies: a
    router-level dependency only runs for handlers that declare it as a
    parameter, so dropping this would silently leave the route
    unauthenticated."""
    try:
        return await price_service.get_price_info(db_session, steam_app_id)
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_CHEAPSHARK_UNAVAILABLE) from error


@get("/api/games/key-shop-prices")
async def get_key_shop_prices(
    title: Annotated[str, QueryParameter(min_length=1)], current_user: NamedDependency[User]
) -> list[KeyShopOffer]:
    """current_user is unused (see get_game_price's identical comment
    above - price data isn't user-specific, but the parameter must stay
    declared for the router's auth dependency to run)."""
    return await key_shop_price_service.search_key_shops(title)


authenticated_games_router = Router(
    path="",
    route_handlers=[
        search_game,
        enriched_search,
        get_game,
        get_game_time_to_beat,
        get_platform,
        get_cover,
        get_genre,
        get_steamgriddb_covers,
        get_game_price,
        get_key_shop_prices,
    ],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
)

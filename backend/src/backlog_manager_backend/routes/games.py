from litestar import get
from litestar.exceptions import ServiceUnavailableException
from litestar.params import FromPath, FromQuery

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
    IGDBGameData,
    IGDBGameTimeToBeat,
    IGDBGenre,
    IGDBPlatform,
    IGDBSearchResult,
)
from backlog_manager_backend.services import game_service

_IGDB_NOT_CONFIGURED = "IGDB integration is not configured"


async def _igdb_credentials() -> tuple[str, str]:
    if not settings.igdb_client_id:
        raise ServiceUnavailableException(_IGDB_NOT_CONFIGURED)
    try:
        access_token = await game_service.get_valid_token()
    except RuntimeError as error:
        raise ServiceUnavailableException(_IGDB_NOT_CONFIGURED) from error
    return settings.igdb_client_id, access_token


@get("/api/games/search")
async def search_game(search_term: FromQuery[str]) -> list[IGDBSearchResult]:
    client_id, access_token = await _igdb_credentials()
    return await search_game_on_igdb(search_term, client_id, access_token)


@get("/api/games/enriched-search")
async def enriched_search(search_term: FromQuery[str]) -> list[EnrichedResult]:
    try:
        return await game_service.search(search_term)
    except RuntimeError as error:
        raise ServiceUnavailableException(_IGDB_NOT_CONFIGURED) from error


@get("/api/games/{game_id:int}")
async def get_game(game_id: FromPath[int]) -> list[IGDBGameData]:
    client_id, access_token = await _igdb_credentials()
    return await get_game_on_igdb(str(game_id), client_id, access_token)


@get("/api/games/{game_id:int}/time-to-beat")
async def get_game_time_to_beat(game_id: FromPath[int]) -> list[IGDBGameTimeToBeat]:
    client_id, access_token = await _igdb_credentials()
    return await get_game_time_to_beat_on_igdb(game_id, client_id, access_token)


@get("/api/games/platforms/{platform_id:int}")
async def get_platform(platform_id: FromPath[int]) -> list[IGDBPlatform]:
    client_id, access_token = await _igdb_credentials()
    return await get_platform_on_igdb(platform_id, client_id, access_token)


@get("/api/games/covers/{cover_id:int}")
async def get_cover(cover_id: FromPath[int]) -> list[IGDBCover]:
    client_id, access_token = await _igdb_credentials()
    return await get_cover_on_igdb(cover_id, client_id, access_token)


@get("/api/games/genres/{genre_id:int}")
async def get_genre(genre_id: FromPath[int]) -> list[IGDBGenre]:
    client_id, access_token = await _igdb_credentials()
    return await get_genre_on_igdb(genre_id, client_id, access_token)

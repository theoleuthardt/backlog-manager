import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import (
    IGDBCover,
    IGDBGameData,
    IGDBGameTimeToBeat,
    IGDBGenre,
    IGDBPlatform,
    IGDBSearchResult,
    IGDBTokenResponse,
)

logger = structlog.get_logger()

_TIMEOUT = httpx.Timeout(60.0)


async def generate_igdb_token(client_id: str, client_secret: str) -> IGDBTokenResponse:
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.post(
                "https://id.twitch.tv/oauth2/token",
                params={
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "grant_type": "client_credentials",
                },
            )
    except httpx.HTTPError as error:
        logger.error("Error generating IGDB token", error=str(error))
        raise

    if response.status_code >= 400:
        logger.error("IGDB API error", status_code=response.status_code)
        raise httpx.HTTPStatusError(
            f"Failed to generate IGDB token: {response.status_code}",
            request=response.request,
            response=response,
        )

    return msgspec.json.decode(response.content, type=IGDBTokenResponse)


async def _query_igdb[T](
    endpoint: str,
    body: str,
    client_id: str,
    access_token: str,
    result_type: type[T],
) -> T:
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.post(
                f"https://api.igdb.com/v4/{endpoint}",
                content=body,
                headers={
                    "Accept": "application/json",
                    "Authorization": f"Bearer {access_token}",
                    "Client-ID": client_id,
                },
            )
    except httpx.HTTPError as error:
        logger.error(f"Error querying IGDB {endpoint}", error=str(error))
        raise

    if response.status_code >= 400:
        logger.error("IGDB API error", status_code=response.status_code)
        raise httpx.HTTPStatusError(
            f"IGDB API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        return msgspec.json.decode(response.content, type=result_type)
    except msgspec.DecodeError as error:
        logger.error(f"Malformed IGDB {endpoint} response", error=str(error))
        raise httpx.HTTPStatusError(
            f"Malformed IGDB {endpoint} response: {error}",
            request=response.request,
            response=response,
        ) from error


_SEARCH_RAW_RESULT_LIMIT = 50


async def search_game_on_igdb(
    search_term: str, client_id: str, access_token: str
) -> list[IGDBSearchResult]:
    """Raw IGDB `/search` hits for a title - alternate names, DLC,
    bundles and character names all match alongside the base game, and
    IGDB defaults to only 10 results per query if no `limit` is given.
    A generous raw limit here gives the caller (game_service.search)
    enough candidates to resolve, dedupe and rank by category before
    truncating to what's actually shown."""
    escaped_term = search_term.replace('"', '\\"')
    body = (
        "fields alternative_name,character,checksum,collection,company,description,"
        "game,name,platform,published_at,test_dummy,theme; "
        f'where name ~ *"{escaped_term}"*; limit {_SEARCH_RAW_RESULT_LIMIT};'
    )
    try:
        return await _query_igdb("search", body, client_id, access_token, list[IGDBSearchResult])
    except httpx.HTTPStatusError:
        return []


async def get_game_on_igdb(game_id: str, client_id: str, access_token: str) -> list[IGDBGameData]:
    body = (
        "fields age_ratings,aggregated_rating,aggregated_rating_count,alternative_names,"
        "artworks,bundles,category,checksum,collection,collections,cover,created_at,dlcs,"
        "expanded_games,expansions,external_games,first_release_date,follows,forks,"
        "franchise,franchises,game_engines,game_localizations,game_modes,game_status,"
        "game_type,genres,hypes,involved_companies,keywords,language_supports,"
        "multiplayer_modes,name,parent_game,platforms,player_perspectives,ports,rating,"
        "rating_count,release_dates,remakes,remasters,screenshots,similar_games,slug,"
        "standalone_expansions,status,storyline,summary,tags,themes,total_rating,"
        "total_rating_count,updated_at,url,version_parent,version_title,videos,websites;"
        f" where id = {game_id};"
    )
    try:
        return await _query_igdb("games", body, client_id, access_token, list[IGDBGameData])
    except httpx.HTTPStatusError:
        return []


async def get_platform_on_igdb(
    platform_id: int, client_id: str, access_token: str
) -> list[IGDBPlatform]:
    body = (
        "fields abbreviation,alternative_name,category,checksum,created_at,generation,"
        "name,platform_family,platform_logo,platform_type,slug,summary,updated_at,url,"
        f"versions,websites; where id = {platform_id};"
    )
    try:
        return await _query_igdb("platforms", body, client_id, access_token, list[IGDBPlatform])
    except httpx.HTTPStatusError:
        return []


async def get_game_time_to_beat_on_igdb(
    game_id: int, client_id: str, access_token: str
) -> list[IGDBGameTimeToBeat]:
    body = (
        "fields checksum,completely,count,created_at,game_id,hastily,normally,updated_at; "
        f"where game_id = {game_id};"
    )
    try:
        return await _query_igdb(
            "game_time_to_beats", body, client_id, access_token, list[IGDBGameTimeToBeat]
        )
    except httpx.HTTPStatusError:
        return []


async def get_cover_on_igdb(cover_id: int, client_id: str, access_token: str) -> list[IGDBCover]:
    body = (
        "fields alpha_channel,animated,checksum,game,game_localization,height,image_id,"
        f"url,width; where id = {cover_id};"
    )
    try:
        return await _query_igdb("covers", body, client_id, access_token, list[IGDBCover])
    except httpx.HTTPStatusError:
        return []


async def get_genre_on_igdb(genre_id: int, client_id: str, access_token: str) -> list[IGDBGenre]:
    body = f"fields checksum,created_at,name,slug,updated_at,url; where id = {genre_id};"
    try:
        return await _query_igdb("genres", body, client_id, access_token, list[IGDBGenre])
    except httpx.HTTPStatusError:
        return []


def _id_list(ids: list[int]) -> str:
    return f"({','.join(str(i) for i in ids)})"


async def get_games_on_igdb(
    game_ids: list[int], client_id: str, access_token: str
) -> list[IGDBGameData]:
    """Batches multiple games into one request via `id = (1,2,3)` instead
    of one request per game - the fix for issue #105's N+1 search
    slowdown. `limit 500;` is required: IGDB defaults to 10 results per
    query, which would otherwise silently truncate a batch this size."""
    if not game_ids:
        return []
    body = (
        "fields age_ratings,aggregated_rating,aggregated_rating_count,alternative_names,"
        "artworks,bundles,category,checksum,collection,collections,cover,created_at,dlcs,"
        "expanded_games,expansions,external_games,first_release_date,follows,forks,"
        "franchise,franchises,game_engines,game_localizations,game_modes,game_status,"
        "game_type,genres,hypes,involved_companies,keywords,language_supports,"
        "multiplayer_modes,name,parent_game,platforms,player_perspectives,ports,rating,"
        "rating_count,release_dates,remakes,remasters,screenshots,similar_games,slug,"
        "standalone_expansions,status,storyline,summary,tags,themes,total_rating,"
        "total_rating_count,updated_at,url,version_parent,version_title,videos,websites;"
        f" where id = {_id_list(game_ids)}; limit 500;"
    )
    try:
        return await _query_igdb("games", body, client_id, access_token, list[IGDBGameData])
    except httpx.HTTPStatusError:
        return []


async def get_covers_on_igdb(
    cover_ids: list[int], client_id: str, access_token: str
) -> list[IGDBCover]:
    if not cover_ids:
        return []
    body = (
        "fields alpha_channel,animated,checksum,game,game_localization,height,image_id,"
        f"url,width; where id = {_id_list(cover_ids)}; limit 500;"
    )
    try:
        return await _query_igdb("covers", body, client_id, access_token, list[IGDBCover])
    except httpx.HTTPStatusError:
        return []


async def get_genres_on_igdb(
    genre_ids: list[int], client_id: str, access_token: str
) -> list[IGDBGenre]:
    if not genre_ids:
        return []
    body = (
        "fields checksum,created_at,name,slug,updated_at,url;"
        f" where id = {_id_list(genre_ids)}; limit 500;"
    )
    try:
        return await _query_igdb("genres", body, client_id, access_token, list[IGDBGenre])
    except httpx.HTTPStatusError:
        return []


async def get_platforms_on_igdb(
    platform_ids: list[int], client_id: str, access_token: str
) -> list[IGDBPlatform]:
    if not platform_ids:
        return []
    body = (
        "fields abbreviation,alternative_name,category,checksum,created_at,generation,"
        "name,platform_family,platform_logo,platform_type,slug,summary,updated_at,url,"
        f"versions,websites; where id = {_id_list(platform_ids)}; limit 500;"
    )
    try:
        return await _query_igdb("platforms", body, client_id, access_token, list[IGDBPlatform])
    except httpx.HTTPStatusError:
        return []


async def get_games_time_to_beat_on_igdb(
    game_ids: list[int], client_id: str, access_token: str
) -> list[IGDBGameTimeToBeat]:
    if not game_ids:
        return []
    body = (
        "fields checksum,completely,count,created_at,game_id,hastily,normally,updated_at;"
        f" where game_id = {_id_list(game_ids)}; limit 500;"
    )
    try:
        return await _query_igdb(
            "game_time_to_beats", body, client_id, access_token, list[IGDBGameTimeToBeat]
        )
    except httpx.HTTPStatusError:
        return []

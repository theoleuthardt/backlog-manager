from urllib.parse import quote

import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import (
    SteamGridDBGrid,
    SteamGridDBGridsEnvelope,
    SteamGridDBSearchEnvelope,
    SteamGridDBSearchResult,
)

logger = structlog.get_logger()

_GRIDS_BY_STEAM_APP_ID_URL = "https://www.steamgriddb.com/api/v2/grids/steam/{steam_app_id}"
_GRIDS_BY_GAME_ID_URL = "https://www.steamgriddb.com/api/v2/grids/game/{game_id}"
_SEARCH_URL = "https://www.steamgriddb.com/api/v2/search/autocomplete/{term}"
_GRID_DIMENSIONS = {"dimensions": "600x900,342x482"}


async def _get(url: str, api_key: str, params: dict[str, str] | None = None) -> httpx.Response:
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                url, headers={"Authorization": f"Bearer {api_key}"}, params=params
            )
    except httpx.HTTPError as error:
        logger.error("SteamGridDB request error", error=str(error))
        raise

    if response.status_code >= 400 and response.status_code != 404:
        raise httpx.HTTPStatusError(
            f"SteamGridDB API error: {response.status_code}",
            request=response.request,
            response=response,
        )
    return response


def _decode_grids(response: httpx.Response) -> list[SteamGridDBGrid]:
    if response.status_code == 404:
        return []
    try:
        envelope = msgspec.json.decode(response.content, type=SteamGridDBGridsEnvelope)
    except msgspec.DecodeError as error:
        logger.error("SteamGridDB grids decode error", error=str(error))
        raise httpx.DecodingError("SteamGridDB API returned an invalid response") from error
    return envelope.data if envelope.success else []


async def get_grids_by_steam_app_id(steam_app_id: int, api_key: str) -> list[SteamGridDBGrid]:
    """Covers for one game, looked up directly by Steam App ID rather
    than SteamGridDB's own game id - avoids a separate title-search
    round trip since callers already have (or have resolved) the App
    ID. Returns [] rather than raising when SteamGridDB has no grids
    for this app (404, or 200 with success: false) - that's an empty
    match, not a failure; still raises on transport/HTTP/decode errors
    like get_owned_games. Restricted to the 2:3 portrait "grid" sizes
    (600x900, 342x482) - without a dimensions filter SteamGridDB also
    returns wide banner/hero-style grids, which get cropped down to a
    thin sliver when forced into the app's portrait cover boxes."""
    response = await _get(
        _GRIDS_BY_STEAM_APP_ID_URL.format(steam_app_id=steam_app_id), api_key, _GRID_DIMENSIONS
    )
    return _decode_grids(response)


async def get_grids_by_steamgriddb_id(game_id: int, api_key: str) -> list[SteamGridDBGrid]:
    """Same as get_grids_by_steam_app_id, but by SteamGridDB's own game
    id instead of a Steam App ID - the only way to fetch covers for a
    title with no Steam App ID (non-Steam and fan games), resolved
    first via search_steamgriddb_games."""
    response = await _get(
        _GRIDS_BY_GAME_ID_URL.format(game_id=game_id), api_key, _GRID_DIMENSIONS
    )
    return _decode_grids(response)


async def search_steamgriddb_games(term: str, api_key: str) -> list[SteamGridDBSearchResult]:
    """Title search against SteamGridDB's own catalogue (distinct from
    both IGDB's and Steam's) - lets a title with no Steam App ID still
    get matched to a SteamGridDB game id for get_grids_by_steamgriddb_id."""
    response = await _get(_SEARCH_URL.format(term=quote(term)), api_key)
    if response.status_code == 404:
        return []
    try:
        envelope = msgspec.json.decode(response.content, type=SteamGridDBSearchEnvelope)
    except msgspec.DecodeError as error:
        logger.error("SteamGridDB search decode error", error=str(error))
        raise httpx.DecodingError("SteamGridDB API returned an invalid response") from error
    return envelope.data if envelope.success else []

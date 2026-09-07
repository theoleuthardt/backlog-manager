import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import SteamGridDBGrid, SteamGridDBGridsEnvelope

logger = structlog.get_logger()

_GRIDS_BY_STEAM_APP_ID_URL = "https://www.steamgriddb.com/api/v2/grids/steam/{steam_app_id}"


async def get_grids_by_steam_app_id(steam_app_id: int, api_key: str) -> list[SteamGridDBGrid]:
    """Covers for one game, looked up directly by Steam App ID rather
    than SteamGridDB's own game id - avoids a separate title-search
    round trip since callers already have (or have resolved) the App
    ID. Returns [] rather than raising when SteamGridDB has no grids
    for this app (404, or 200 with success: false) - that's an empty
    match, not a failure; still raises on transport/HTTP/decode errors
    like get_owned_games."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                _GRIDS_BY_STEAM_APP_ID_URL.format(steam_app_id=steam_app_id),
                headers={"Authorization": f"Bearer {api_key}"},
            )
    except httpx.HTTPError as error:
        logger.error("SteamGridDB grids error", error=str(error))
        raise

    if response.status_code == 404:
        return []
    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"SteamGridDB API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        envelope = msgspec.json.decode(response.content, type=SteamGridDBGridsEnvelope)
    except msgspec.DecodeError as error:
        logger.error("SteamGridDB grids decode error", error=str(error))
        raise httpx.DecodingError("SteamGridDB API returned an invalid response") from error

    return envelope.data if envelope.success else []

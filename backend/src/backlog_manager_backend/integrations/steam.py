import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import SteamGetOwnedGamesEnvelope, SteamOwnedGame

logger = structlog.get_logger()

_BASE_URL = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/"


async def get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
    """Raises on failure (timeout, non-2xx, malformed body) rather than
    swallowing it, unlike search_game_on_hltb - a sync the user
    explicitly triggered should surface an error instead of silently
    doing nothing."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                _BASE_URL,
                params={
                    "key": api_key,
                    "steamid": steam_id,
                    "include_appinfo": 1,
                    "format": "json",
                },
            )
    except httpx.HTTPError as error:
        logger.error("GetOwnedGames error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"Steam Web API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    envelope = msgspec.json.decode(response.content, type=SteamGetOwnedGamesEnvelope)
    return envelope.response.games

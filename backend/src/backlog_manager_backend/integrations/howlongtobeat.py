import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import HltbResultData

logger = structlog.get_logger()

_BASE_URL = "https://hltbapi1.azurewebsites.net/hltb"


async def search_game_on_hltb(search_term: str) -> list[HltbResultData]:
    """On any failure (timeout, non-2xx, malformed body) returns an empty
    list rather than raising, matching the existing TS fallback-on-error
    behavior."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(60.0)) as client:
            response = await client.post(
                f"{_BASE_URL}/search",
                json={"searchTerm": search_term, "matchType": 1, "platform": ""},
            )
    except httpx.HTTPError as error:
        logger.error("SearchGame error", error=str(error))
        return []

    if response.status_code >= 400:
        logger.error("HowLongToBeat API error", status_code=response.status_code)
        return []

    try:
        return msgspec.json.decode(response.content, type=list[HltbResultData])
    except msgspec.DecodeError:
        return []


async def get_game_by_id_on_hltb(hltb_id: int) -> HltbResultData:
    """Raises on failure (timeout, non-2xx) since callers rely on the
    exception, matching the existing TS behavior of re-throwing."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(8.0)) as client:
            response = await client.get(f"{_BASE_URL}/{hltb_id}")
    except httpx.HTTPError as error:
        logger.error("GetGameByID error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"HowLongToBeat API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    return msgspec.json.decode(response.content, type=HltbResultData)

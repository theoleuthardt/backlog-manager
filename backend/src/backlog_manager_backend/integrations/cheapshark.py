import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import (
    CheapSharkGameDetail,
    CheapSharkGameLookup,
    CheapSharkStore,
)

logger = structlog.get_logger()

_BASE_URL = "https://www.cheapshark.com/api/1.0"
_INVALID_RESPONSE = "CheapShark API returned an invalid response"
_USER_AGENT = "BacklogManager/1.0 (https://github.com/theoleuthardt/backlog-manager)"
"""CheapShark rejects requests with a missing or generic (e.g. httpx's
default "python-httpx/x.y.z") User-Agent with a 400 - see
https://apidocs.cheapshark.com/."""


async def _get(path: str, params: dict[str, str]) -> httpx.Response:
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                f"{_BASE_URL}{path}", params=params, headers={"User-Agent": _USER_AGENT}
            )
    except httpx.HTTPError as error:
        logger.error("CheapShark request error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"CheapShark API error: {response.status_code}",
            request=response.request,
            response=response,
        )
    return response


async def find_cheapshark_game_id(steam_app_id: int) -> int | None:
    """Resolves a Steam App ID to CheapShark's own internal game ID, the
    key get_cheapshark_game_detail needs - returns None (not an error)
    when CheapShark has no match for this app."""
    response = await _get("/games", {"steamAppID": str(steam_app_id)})
    try:
        matches = msgspec.json.decode(response.content, type=list[CheapSharkGameLookup])
    except msgspec.DecodeError as error:
        logger.error("CheapShark game lookup decode error", error=str(error))
        raise httpx.DecodingError(_INVALID_RESPONSE) from error

    return int(matches[0].gameID) if matches else None


async def get_cheapshark_game_detail(cheapshark_game_id: int) -> CheapSharkGameDetail:
    """Current deals across every tracked store plus the all-time-low
    price (cheapestPriceEver) for one CheapShark game ID."""
    response = await _get("/games", {"id": str(cheapshark_game_id)})
    try:
        return msgspec.json.decode(response.content, type=CheapSharkGameDetail)
    except msgspec.DecodeError as error:
        logger.error("CheapShark game detail decode error", error=str(error))
        raise httpx.DecodingError(_INVALID_RESPONSE) from error


async def get_stores() -> list[CheapSharkStore]:
    response = await _get("/stores", {})
    try:
        return msgspec.json.decode(response.content, type=list[CheapSharkStore])
    except msgspec.DecodeError as error:
        logger.error("CheapShark stores decode error", error=str(error))
        raise httpx.DecodingError(_INVALID_RESPONSE) from error

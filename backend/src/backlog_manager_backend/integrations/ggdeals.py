import logging

import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import GgDealsGame, GgDealsPricesAnswer

logger = structlog.get_logger()

logging.getLogger("httpx").setLevel(logging.WARNING)
"""The API key travels in the query string, so httpx's own INFO line per
request (it prints the whole URL) must never be written."""

_URL = "https://api.gg.deals/v1/prices/by-steam-app-id/"
_INVALID_RESPONSE = "GG.deals API returned an invalid response"
_USER_AGENT = "BacklogManager/1.0 (https://github.com/theoleuthardt/backlog-manager)"


async def get_prices_by_steam_app_ids(
    steam_app_ids: list[int], api_key: str
) -> dict[int, GgDealsGame | None]:
    """The prices of up to a hundred games in one request (every id counts
    against the rate limit of the key: 100 per minute, 1000 per hour). A
    game GG.deals does not know is None. An error status raises
    httpx.HTTPStatusError (429 when the limit is used up, nothing is
    returned then); neither the key nor the URL appears in any message or
    log line."""
    if not steam_app_ids:
        return {}
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                _URL,
                params={"ids": ",".join(str(i) for i in steam_app_ids), "key": api_key},
                headers={"User-Agent": _USER_AGENT},
            )
    except httpx.HTTPError as error:
        logger.error("GG.deals request error", error_type=type(error).__name__)
        raise
    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"GG.deals API error: {response.status_code}",
            request=response.request,
            response=response,
        )
    try:
        answer = msgspec.json.decode(response.content, type=GgDealsPricesAnswer)
    except msgspec.DecodeError as error:
        logger.error("GG.deals decode error", error=str(error))
        raise httpx.DecodingError(_INVALID_RESPONSE) from error
    if not answer.success:
        raise httpx.DecodingError(_INVALID_RESPONSE)
    return {steam_app_id: answer.data.get(str(steam_app_id)) for steam_app_id in steam_app_ids}

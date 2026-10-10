import asyncio

import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import (
    SteamAchievementSchema,
    SteamAppDetails,
    SteamAppDetailsEntry,
    SteamGetOwnedGamesEnvelope,
    SteamGetPlayerAchievementsEnvelope,
    SteamGetSchemaForGameEnvelope,
    SteamGetWishlistEnvelope,
    SteamOwnedGame,
    SteamPlayerStats,
    SteamStoreBrowseEnvelope,
    SteamStoreItemAssets,
    SteamStoreSearchEnvelope,
    SteamStoreSearchItem,
    SteamWishlistItem,
)

logger = structlog.get_logger()

_BASE_URL = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/"
_PLAYER_ACHIEVEMENTS_URL = (
    "https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v0001/"
)
_SCHEMA_FOR_GAME_URL = "https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/"
_WISHLIST_URL = "https://api.steampowered.com/IWishlistService/GetWishlist/v1/"
_APP_DETAILS_URL = "https://store.steampowered.com/api/appdetails"
_STORE_SEARCH_URL = "https://store.steampowered.com/api/storesearch/"
_STORE_BROWSE_ITEMS_URL = "https://api.steampowered.com/IStoreBrowseService/GetItems/v1"
_STORE_ASSETS_BASE_URL = "https://shared.steamstatic.com/store_item_assets/"
STORE_ITEMS_BATCH_SIZE = 50
STORE_ITEMS_BATCH_PAUSE_SECONDS = 0.5
_STORE_ITEM_RESOLVED = 1
_RETRY_STATUS_CODES = frozenset({429, 500, 502, 503, 504})
_RETRY_DELAYS_SECONDS = (1.0, 3.0)


async def get_owned_games(steam_id: str, api_key: str) -> list[SteamOwnedGame]:
    """Raises on failure (timeout, non-2xx, malformed body) rather than
    swallowing it, unlike search_game_on_hltb - a sync the user
    explicitly triggered should surface an error instead of silently
    doing nothing.

    include_played_free_games=1 is required or Steam silently drops
    every free-to-play game (Team Fortress 2, Dota 2, ...) from the
    response regardless of playtime."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                _BASE_URL,
                params={
                    "key": api_key,
                    "steamid": steam_id,
                    "include_appinfo": 1,
                    "include_played_free_games": 1,
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

    try:
        envelope = msgspec.json.decode(response.content, type=SteamGetOwnedGamesEnvelope)
    except msgspec.DecodeError as error:
        logger.error("GetOwnedGames decode error", error=str(error))
        raise httpx.DecodingError("Steam Web API returned an invalid response") from error

    return envelope.response.games


async def search_store_by_title(title: str) -> list[SteamStoreSearchItem]:
    """Steam storefront search for a title (no API key needed), backing
    game_service.find_steam_app_id after ISteamApps/GetAppList was
    retired. Steam returns its own relevance ranking, so callers take the
    first type=="app" hit rather than re-sorting. Raises on failure like
    get_owned_games; the caller treats that as non-fatal, since this is a
    best-effort lookup."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(10.0)) as client:
            response = await client.get(
                _STORE_SEARCH_URL, params={"term": title, "cc": "US", "l": "en"}
            )
    except httpx.HTTPError as error:
        logger.error("StoreSearch error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"Steam store API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        envelope = msgspec.json.decode(response.content, type=SteamStoreSearchEnvelope)
    except msgspec.DecodeError as error:
        logger.error("StoreSearch decode error", error=str(error))
        raise httpx.DecodingError("Steam store API returned an invalid response") from error

    return envelope.items


async def get_steam_library_cover_if_exists(app_id: int) -> str | None:
    """Resolves Steam's official vertical library cover for the app. The
    deterministic 600x900 path is tried first (HEAD returns 200); many apps
    only serve their capsule from a hashed storefront asset path, so a miss
    falls back to the store browse API's asset listing. Returns None when
    neither yields a cover or a lookup fails."""
    url = f"https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{app_id}/library_600x900.jpg"
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as client:
            response = await client.head(url, follow_redirects=True)
            if response.status_code == 200:
                return url
    except httpx.HTTPError as error:
        logger.error("get_steam_library_cover error", app_id=app_id, error=str(error))
    return await _get_hashed_library_cover(app_id)


async def _get_hashed_library_cover(app_id: int) -> str | None:
    """Library capsule URL from the store browse API's asset listing, the
    2x variant preferred. Best-effort: any HTTP or decode failure, or an
    app without library assets, yields None."""
    input_json = msgspec.json.encode(
        {
            "ids": [{"appid": app_id}],
            "context": {"language": "english", "country_code": "US"},
            "data_request": {"include_assets": True},
        }
    ).decode()
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as client:
            response = await client.get(_STORE_BROWSE_ITEMS_URL, params={"input_json": input_json})
        response.raise_for_status()
        envelope = msgspec.json.decode(response.content, type=SteamStoreBrowseEnvelope)
    except (httpx.HTTPError, msgspec.DecodeError) as error:
        logger.error("store browse assets error", app_id=app_id, error=str(error))
        return None

    for item in envelope.response.store_items:
        if item.id != app_id or item.assets is None:
            continue
        filename = item.assets.library_capsule_2x or item.assets.library_capsule
        if filename is not None:
            path = item.assets.asset_url_format.replace("${FILENAME}", filename)
            return f"{_STORE_ASSETS_BASE_URL}{path}"
    return None


async def _get_with_retry(url: str, params: dict[str, str | int], timeout: float) -> httpx.Response:
    """GET that waits and tries again when the store rate-limits (429) or
    has a server error, up to len(_RETRY_DELAYS_SECONDS) more times. The
    store's appdetails endpoint allows only a few hundred requests per
    five minutes per address, so a long wishlist hits that limit; without
    a retry every item past it came back nameless. The last response is
    returned whatever its status, the caller decides what to do with it."""
    attempts = len(_RETRY_DELAYS_SECONDS) + 1
    for attempt in range(attempts):
        async with httpx.AsyncClient(timeout=httpx.Timeout(timeout)) as client:
            response = await client.get(url, params=params)
        if response.status_code not in _RETRY_STATUS_CODES or attempt == attempts - 1:
            return response
        await asyncio.sleep(_RETRY_DELAYS_SECONDS[attempt])
    return response


def _store_header_url(assets: SteamStoreItemAssets | None) -> str | None:
    if assets is None or assets.header is None:
        return None
    path = assets.asset_url_format.replace("${FILENAME}", assets.header)
    return f"{_STORE_ASSETS_BASE_URL}{path}"


async def get_store_items(app_ids: list[int]) -> dict[int, SteamAppDetails]:
    """Names and header images for many apps with one request per
    STORE_ITEMS_BATCH_SIZE, through the store browse API (no key needed).
    Unlike appdetails this is made for lists and does not hit a request
    limit for a wishlist of a few hundred games. Apps the store does not
    resolve (unknown, removed) are absent from the result. Raises on
    transport or HTTP failure like get_wishlist; callers fall back to
    appdetails."""
    details: dict[int, SteamAppDetails] = {}
    for start in range(0, len(app_ids), STORE_ITEMS_BATCH_SIZE):
        if start:
            await asyncio.sleep(STORE_ITEMS_BATCH_PAUSE_SECONDS)
        chunk = app_ids[start : start + STORE_ITEMS_BATCH_SIZE]
        input_json = msgspec.json.encode(
            {
                "ids": [{"appid": app_id} for app_id in chunk],
                "context": {"language": "english", "country_code": "US"},
                "data_request": {"include_basic_info": True, "include_assets": True},
            }
        ).decode()
        try:
            response = await _get_with_retry(
                _STORE_BROWSE_ITEMS_URL, {"input_json": input_json}, 15.0
            )
        except httpx.HTTPError as error:
            logger.error("store browse items error", error=str(error))
            raise
        if response.status_code >= 400:
            raise httpx.HTTPStatusError(
                f"Steam store API error: {response.status_code}",
                request=response.request,
                response=response,
            )
        try:
            envelope = msgspec.json.decode(response.content, type=SteamStoreBrowseEnvelope)
        except msgspec.DecodeError as error:
            logger.error("store browse items decode error", error=str(error))
            raise httpx.DecodingError("Steam store API returned an invalid response") from error
        for item in envelope.response.store_items:
            if item.success == _STORE_ITEM_RESOLVED and item.name:
                details[item.id] = SteamAppDetails(
                    name=item.name, header_image=_store_header_url(item.assets)
                )
    return details


async def get_app_details(app_id: int) -> SteamAppDetails | None:
    try:
        response = await _get_with_retry(_APP_DETAILS_URL, {"appids": app_id}, 15.0)
    except httpx.HTTPError as error:
        logger.error("appdetails error", app_id=app_id, error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"Steam store API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        envelope = msgspec.json.decode(response.content, type=dict[str, SteamAppDetailsEntry])
    except msgspec.DecodeError as error:
        logger.error("appdetails decode error", app_id=app_id, error=str(error))
        raise httpx.DecodingError("Steam store API returned an invalid response") from error

    entry = envelope.get(str(app_id))
    if entry is None or not entry.success or entry.data is None:
        return None
    return entry.data


async def get_player_achievements(steam_id: str, app_id: int, api_key: str) -> SteamPlayerStats:
    """Raises on transport/HTTP/decode failure like get_owned_games.
    playerstats.success is false (not an exception) when the app has
    no stats, or the profile/game details aren't public - callers
    treat that as "no achievement data available" rather than an
    error. l=english so the response includes each achievement's
    name/description, not just its apiname/achieved flag."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                _PLAYER_ACHIEVEMENTS_URL,
                params={
                    "appid": app_id,
                    "key": api_key,
                    "steamid": steam_id,
                    "l": "english",
                    "format": "json",
                },
            )
    except httpx.HTTPError as error:
        logger.error("GetPlayerAchievements error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"Steam Web API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        envelope = msgspec.json.decode(response.content, type=SteamGetPlayerAchievementsEnvelope)
    except msgspec.DecodeError as error:
        logger.error("GetPlayerAchievements decode error", error=str(error))
        raise httpx.DecodingError("Steam Web API returned an invalid response") from error

    return envelope.playerstats


async def get_achievement_schema(app_id: int, api_key: str) -> list[SteamAchievementSchema]:
    """Static per-game achievement metadata (display name, description,
    icon URLs) - unlike get_player_achievements, this carries no
    per-user data, so callers can cache it indefinitely per app_id."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(
                _SCHEMA_FOR_GAME_URL,
                params={"appid": app_id, "key": api_key, "format": "json"},
            )
    except httpx.HTTPError as error:
        logger.error("GetSchemaForGame error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"Steam Web API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        envelope = msgspec.json.decode(response.content, type=SteamGetSchemaForGameEnvelope)
    except msgspec.DecodeError as error:
        logger.error("GetSchemaForGame decode error", error=str(error))
        raise httpx.DecodingError("Steam Web API returned an invalid response") from error

    available_game_stats = envelope.game.available_game_stats
    return available_game_stats.achievements if available_game_stats else []


async def get_wishlist(steam_id: str) -> list[SteamWishlistItem]:
    """Fetches a Steam profile's wishlist via the undocumented
    IWishlistService/GetWishlist endpoint - it needs no API key but
    only ever returns data for profiles whose wishlist is public;
    private profiles yield an empty response (items omitted), like
    GetOwnedGames. Raises on transport/HTTP/decode failure like
    get_owned_games."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(_WISHLIST_URL, params={"steamid": steam_id})
    except httpx.HTTPError as error:
        logger.error("GetWishlist error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"Steam Web API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        envelope = msgspec.json.decode(response.content, type=SteamGetWishlistEnvelope)
    except msgspec.DecodeError as error:
        logger.error("GetWishlist decode error", error=str(error))
        raise httpx.DecodingError("Steam Web API returned an invalid response") from error

    return envelope.response.items

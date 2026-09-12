import httpx
import msgspec
import structlog

from backlog_manager_backend.integrations.types import (
    SteamAchievementSchema,
    SteamApp,
    SteamAppDetails,
    SteamAppDetailsEntry,
    SteamGetAppListEnvelope,
    SteamGetOwnedGamesEnvelope,
    SteamGetPlayerAchievementsEnvelope,
    SteamGetSchemaForGameEnvelope,
    SteamGetWishlistEnvelope,
    SteamOwnedGame,
    SteamPlayerStats,
    SteamWishlistItem,
)

logger = structlog.get_logger()

_BASE_URL = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/"
_APP_LIST_URL = "https://api.steampowered.com/ISteamApps/GetAppList/v2/"
_PLAYER_ACHIEVEMENTS_URL = "https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v0001/"
_SCHEMA_FOR_GAME_URL = "https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/"
_WISHLIST_URL = "https://api.steampowered.com/IWishlistService/GetWishlist/v1/"
_APP_DETAILS_URL = "https://store.steampowered.com/api/appdetails"


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


async def get_app_list() -> list[SteamApp]:
    """Steam's public catalogue of every app (games, DLC, tools, demos,
    ...) - unlike GetOwnedGames, this needs no API key. Used to look up
    a Steam App ID by title. Raises on failure like get_owned_games;
    the caller (game_service.find_steam_app_id) treats that as
    non-fatal, since this is a best-effort lookup."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(20.0)) as client:
            response = await client.get(_APP_LIST_URL)
    except httpx.HTTPError as error:
        logger.error("GetAppList error", error=str(error))
        raise

    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"Steam Web API error: {response.status_code}",
            request=response.request,
            response=response,
        )

    try:
        envelope = msgspec.json.decode(response.content, type=SteamGetAppListEnvelope)
    except msgspec.DecodeError as error:
        logger.error("GetAppList decode error", error=str(error))
        raise httpx.DecodingError("Steam Web API returned an invalid response") from error

    return envelope.applist.apps


async def get_app_details(app_id: int) -> SteamAppDetails | None:
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
            response = await client.get(_APP_DETAILS_URL, params={"appids": app_id})
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

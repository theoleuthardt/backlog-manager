import asyncio
import re
import time

import httpx
import structlog

from backlog_manager_backend.integrations.howlongtobeat import search_game_on_hltb
from backlog_manager_backend.integrations.igdb import (
    generate_igdb_token,
    get_covers_on_igdb,
    get_games_on_igdb,
    get_games_time_to_beat_on_igdb,
    get_genres_on_igdb,
    get_platforms_on_igdb,
    search_game_on_igdb,
)
from backlog_manager_backend.integrations.steam import get_app_list as get_steam_app_list
from backlog_manager_backend.integrations.steamgriddb import get_grids_by_steam_app_id
from backlog_manager_backend.integrations.types import (
    EnrichedResult,
    IGDBCover,
    IGDBGameData,
    IGDBSearchResult,
)

logger = structlog.get_logger()

_SEARCH_RESULT_LIMIT = 20

# IGDB's /games endpoint's `game_type` enum (formerly called `category`
# in IGDB's docs and in this codebase - that name still exists as a
# field you can request, but IGDB silently returns nothing for it; the
# working field for the same enum is `game_type`). 0 main_game, 8
# remake, 9 remaster, 10 expanded_game rank as "real games" a title
# search should surface, ranked in that order; everything else
# (dlc_addon, expansion, bundle, standalone_expansion, mod, episode,
# season, port, fork, pack, update) is excluded from search results
# entirely by _is_dlc_like below, not just ranked last - see issue
# #154, where these were crowding the base game out of the top results.
_MAIN_GAME_TYPE_RANKS = {0: 0, 8: 1, 9: 1, 10: 1}
_OTHER_GAME_TYPE_RANK = 2
_EXCLUDED_GAME_TYPES = {1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14}

# Keyed by the full (client_id, client_secret) pair rather than a
# single global slot, and rather than client_id alone - two different
# credential pairs (a user's own vs. another user's, or the global
# fallback) must never share a cached access token even if they
# happen to share a client_id, since that would silently spend one
# credential's quota against a request made under a different one.
# The tuple never leaves this process (not logged, not persisted), so
# there's no need to hash it - it's just a dict key.
_token_cache: dict[tuple[str, str], dict[str, object]] = {}
_genre_cache: dict[int, str] = {}
_platform_cache: dict[int, str] = {}
# Unbounded, no-TTL, same style as the genre/platform caches above -
# directly serves issue #105's "cache requests for game information" ask.
_game_cache: dict[int, IGDBGameData] = {}
_cover_cache: dict[int, IGDBCover] = {}
# hltb_id, main_story, main_story_with_extras, completionist - populated
# from whichever source (IGDB or the HLTB fallback) resolved a game, so a
# repeat search for a game IGDB has no beat-time data for doesn't re-fire
# a live HLTB scrape every time.
_time_to_beat_cache: dict[int, tuple[int, float, float, float]] = {}

_STEAM_APP_LIST_TTL_SECONDS = 24 * 60 * 60
_STEAM_APP_LIST_RETRY_BACKOFF_SECONDS = 60

_steam_app_id_by_title: dict[str, int] = {}
_steam_app_list_cached_at: float | None = None
_steam_app_list_last_attempt_at: float | None = None
_steam_app_list_lock = asyncio.Lock()

# Bounded (unlike the IGDB caches above, whose keys only ever come from
# IGDB's own search results) since steam_app_id is a caller-supplied
# query param on the public cover-picker endpoint - an unbounded cache
# keyed by it would let repeated requests for distinct (real or made
# up) app ids grow memory for the life of the worker.
_STEAMGRIDDB_COVER_CACHE_MAX_SIZE = 500
_steamgriddb_cover_cache: dict[int, list[str]] = {}


async def get_valid_token(client_id: str, client_secret: str) -> str:
    """Gets a valid IGDB access token for the given credentials, using
    the cached one if it hasn't expired yet (expires_in is in seconds;
    refreshed 5 minutes early). Cached per (client_id, client_secret)
    pair (see _token_cache) so a caller's credentials never resolve to
    a token generated for a different pair - each user (and the global
    fallback) can have their own IGDB client_id/client_secret pair."""
    if not client_id or not client_secret:
        raise RuntimeError(
            "IGDB credentials not configured. Please set IGDB_CLIENT_ID and "
            "IGDB_CLIENT_SECRET environment variables."
        )

    cache_key = (client_id, client_secret)
    cached = _token_cache.get(cache_key)
    if cached is not None and cached["expires_at"] > time.monotonic():
        return str(cached["access_token"])

    token_response = await generate_igdb_token(client_id, client_secret)
    if not token_response.access_token:
        raise RuntimeError("Failed to generate IGDB access token")

    _token_cache[cache_key] = {
        "access_token": token_response.access_token,
        "expires_at": time.monotonic() + (token_response.expires_in - 300),
    }
    return token_response.access_token


def _is_dlc_like(game: IGDBGameData) -> bool:
    """True for anything a title search shouldn't surface as its own
    result: a game_type IGDB tags as DLC/expansion/bundle/etc, or - for
    the rarer case where game_type itself is missing - any entry that
    links back to a parent_game, which no base game does."""
    if game.game_type in _EXCLUDED_GAME_TYPES:
        return True
    return game.game_type is None and game.parent_game is not None


def _seconds_to_hours(seconds: int | None) -> float:
    return round((seconds / 3600) * 10) / 10 if seconds else 0.0


async def _resolve_time_to_beat(game: IGDBGameData) -> tuple[int, float, float, float]:
    """Resolves (and caches) one game's beat-time, falling back to
    HowLongToBeat when this game had no entry in the batched IGDB
    time-to-beats call. Only reached for cache misses - see
    _enrich_search_results."""
    if game.id in _time_to_beat_cache:
        return _time_to_beat_cache[game.id]

    hltb_id, main_story, main_story_with_extras, completionist = game.id, 0.0, 0.0, 0.0
    if main_story == 0 and main_story_with_extras == 0 and completionist == 0 and game.name:
        try:
            hltb_results = await search_game_on_hltb(game.name)
            hltb_match = hltb_results[0] if hltb_results else None
            if hltb_match:
                hltb_id = hltb_match.hltb_id
                main_story = hltb_match.main_story
                main_story_with_extras = hltb_match.main_story_with_extras
                completionist = hltb_match.completionist
        except httpx.HTTPError:
            logger.error("HLTB fallback failed for game", game_name=game.name)

    result = (hltb_id, main_story, main_story_with_extras, completionist)
    _time_to_beat_cache[game.id] = result
    return result


async def get_game_covers(steam_app_id: int, api_key: str | None) -> list[str]:
    """All SteamGridDB grid image URLs available for a game, highest
    community score first - powers the cover-selection UI for editing
    an existing entry's picture. `api_key` is the caller's resolved key
    (their own, or the global settings.steamgriddb_api_key fallback) -
    see routes/games.py::_resolve_steamgriddb_api_key. Raises
    (RuntimeError if unconfigured, httpx.HTTPError on a request
    failure) rather than swallowing, unlike _try_get_steamgriddb_covers
    below - a user who opened the picker needs to know it failed rather
    than seeing an empty grid."""
    if not api_key:
        raise RuntimeError("SteamGridDB API key not configured")

    if steam_app_id in _steamgriddb_cover_cache:
        return _steamgriddb_cover_cache[steam_app_id]

    grids = await get_grids_by_steam_app_id(steam_app_id, api_key)
    urls = [grid.url for grid in sorted(grids, key=lambda grid: grid.score, reverse=True)]

    if len(_steamgriddb_cover_cache) >= _STEAMGRIDDB_COVER_CACHE_MAX_SIZE:
        _steamgriddb_cover_cache.pop(next(iter(_steamgriddb_cover_cache)))
    _steamgriddb_cover_cache[steam_app_id] = urls
    return urls


async def _try_get_steamgriddb_covers(steam_app_id: int, api_key: str | None) -> list[str]:
    """Best-effort variant of get_game_covers for search enrichment -
    a SteamGridDB failure or missing API key here must not fail the
    whole search, unlike the dedicated cover-picker endpoint."""
    try:
        return await get_game_covers(steam_app_id, api_key)
    except (RuntimeError, httpx.HTTPError):
        return []


async def _resolve_steamgriddb_covers_by_game_id(
    games: list[IGDBGameData], api_key: str | None
) -> dict[int, list[str]]:
    """Resolves Steam App IDs for a page of search results (cheap - an
    in-memory dict lookup once the catalogue is warm) then fetches
    SteamGridDB covers for all of them concurrently instead of one
    game at a time - a SteamGridDB outage would otherwise delay the
    whole search by one request timeout per game, up to
    _SEARCH_RESULT_LIMIT of them."""
    if not api_key:
        return {}

    steam_app_ids_by_game_id: dict[int, int] = {}
    for game in games:
        if game.name:
            steam_app_id = await find_steam_app_id(game.name)
            if steam_app_id is not None:
                steam_app_ids_by_game_id[game.id] = steam_app_id

    if not steam_app_ids_by_game_id:
        return {}

    cover_lists = await asyncio.gather(
        *(
            _try_get_steamgriddb_covers(steam_app_id, api_key)
            for steam_app_id in steam_app_ids_by_game_id.values()
        )
    )
    return dict(zip(steam_app_ids_by_game_id.keys(), cover_lists, strict=True))


async def _enrich_search_results(
    search_results: list[IGDBSearchResult],
    client_id: str,
    access_token: str,
    search_term: str,
    steamgriddb_api_key: str | None,
) -> list[EnrichedResult]:
    """Batches every IGDB lookup needed to enrich a page of search
    results into (at most) one request per data type, instead of one
    request per result per data type - see issue #105. A failure in the
    single batched games call now fails the whole search (returns []),
    trading today's "list gets shorter" behavior for far fewer, far
    less rate-limit-exposed requests; per-game genre/platform/cover
    assembly failures stay isolated below.

    Raw search hits are resolved to game ids, deduped (multiple hits -
    alternate names, character matches - can resolve to the same game),
    filtered to drop anything DLC-like, and ranked by game type
    (main_game/remake/remaster/expanded_game first, an exact
    case-insensitive title match breaking ties within a type - IGDB
    tags some editions, e.g. "SnowRunner: Premium Edition", as their
    own main_game rather than a DLC of the base game) before being
    truncated to _SEARCH_RESULT_LIMIT - see issue #154. Everything past
    that point (covers, genres, platforms,
    beat-time, SteamGridDB) only runs for the final, truncated set.

    An all-zero/empty IGDB time-to-beat record must not be cached as
    "resolved" - that would permanently block the HLTB fallback for a
    game IGDB has no real duration data for. SteamGridDB covers are
    preferred over the IGDB cover when configured and a Steam App ID
    could be resolved for the title, since SteamGridDB has far better
    cover-art availability than IGDB."""
    game_ids = [
        result.game if result.game is not None else result.id for result in search_results
    ]

    uncached_game_ids = [game_id for game_id in game_ids if game_id not in _game_cache]
    if uncached_game_ids:
        try:
            for game in await get_games_on_igdb(uncached_game_ids, client_id, access_token):
                _game_cache[game.id] = game
        except httpx.HTTPError:
            logger.error("Failed to fetch games batch")

    seen_game_ids: set[int] = set()
    unique_game_ids: list[int] = []
    for game_id in game_ids:
        if game_id in _game_cache and game_id not in seen_game_ids:
            seen_game_ids.add(game_id)
            unique_game_ids.append(game_id)

    candidate_game_ids = [
        game_id for game_id in unique_game_ids if not _is_dlc_like(_game_cache[game_id])
    ]

    normalized_search_term = search_term.strip().casefold()

    def _sort_key(game_id: int) -> tuple[int, bool]:
        game = _game_cache[game_id]
        is_exact_title_match = (game.name or "").strip().casefold() == normalized_search_term
        return (
            _MAIN_GAME_TYPE_RANKS.get(game.game_type, _OTHER_GAME_TYPE_RANK),
            not is_exact_title_match,
        )

    ranked_game_ids = sorted(candidate_game_ids, key=_sort_key)[:_SEARCH_RESULT_LIMIT]

    games_by_id = {game_id: _game_cache[game_id] for game_id in ranked_game_ids}
    games = list(games_by_id.values())

    cover_ids = [game.cover for game in games if game.cover]
    uncached_cover_ids = [cover_id for cover_id in cover_ids if cover_id not in _cover_cache]
    if uncached_cover_ids:
        try:
            for cover in await get_covers_on_igdb(uncached_cover_ids, client_id, access_token):
                _cover_cache[cover.id] = cover
        except httpx.HTTPError:
            logger.error("Failed to fetch covers batch")

    genre_ids = {genre_id for game in games for genre_id in (game.genres or [])}
    uncached_genre_ids = [genre_id for genre_id in genre_ids if genre_id not in _genre_cache]
    if uncached_genre_ids:
        try:
            for genre in await get_genres_on_igdb(uncached_genre_ids, client_id, access_token):
                if genre.name:
                    _genre_cache[genre.id] = genre.name
        except httpx.HTTPError:
            logger.error("Failed to fetch genres batch")

    platform_ids = {platform_id for game in games for platform_id in (game.platforms or [])}
    uncached_platform_ids = [
        platform_id for platform_id in platform_ids if platform_id not in _platform_cache
    ]
    if uncached_platform_ids:
        try:
            for platform in await get_platforms_on_igdb(
                uncached_platform_ids, client_id, access_token
            ):
                if platform.name:
                    _platform_cache[platform.id] = platform.name
        except httpx.HTTPError:
            logger.error("Failed to fetch platforms batch")

    time_to_beat_by_game_id: dict[int, tuple[int, float, float, float]] = {}
    uncached_time_to_beat_ids = [
        game.id for game in games if game.id not in _time_to_beat_cache
    ]
    if uncached_time_to_beat_ids:
        try:
            for entry in await get_games_time_to_beat_on_igdb(
                uncached_time_to_beat_ids, client_id, access_token
            ):
                if entry.game_id is not None and any(
                    (entry.hastily, entry.normally, entry.completely)
                ):
                    _time_to_beat_cache[entry.game_id] = (
                        entry.game_id,
                        _seconds_to_hours(entry.hastily),
                        _seconds_to_hours(entry.normally),
                        _seconds_to_hours(entry.completely),
                    )
        except httpx.HTTPError:
            logger.error("Failed to fetch time-to-beat batch")

    games_needing_hltb = [game for game in games if game.id not in _time_to_beat_cache]
    if games_needing_hltb:
        await asyncio.gather(*(_resolve_time_to_beat(game) for game in games_needing_hltb))
    for game in games:
        if game.id in _time_to_beat_cache:
            time_to_beat_by_game_id[game.id] = _time_to_beat_cache[game.id]

    steamgriddb_covers_by_game_id = await _resolve_steamgriddb_covers_by_game_id(
        games, steamgriddb_api_key
    )

    results: list[EnrichedResult] = []
    for game_id in ranked_game_ids:
        game = games_by_id.get(game_id)
        if game is None:
            continue
        try:
            image_url: str | None = None
            cover = _cover_cache.get(game.cover) if game.cover else None
            if cover and cover.image_id:
                image_url = (
                    "https://images.igdb.com/igdb/image/upload/"
                    f"t_cover_big/{cover.image_id}.jpg"
                )

            steamgriddb_urls = steamgriddb_covers_by_game_id.get(game.id, [])
            if steamgriddb_urls:
                image_url = steamgriddb_urls[0]

            genres = [
                _genre_cache[genre_id] for genre_id in (game.genres or []) if genre_id in _genre_cache
            ]
            platforms = [
                _platform_cache[platform_id]
                for platform_id in (game.platforms or [])
                if platform_id in _platform_cache
            ]

            hltb_id, main_story, main_story_with_extras, completionist = (
                time_to_beat_by_game_id.get(game.id, (game.id, 0.0, 0.0, 0.0))
            )

            results.append(
                EnrichedResult(
                    id=game.id,
                    hltb_id=hltb_id,
                    title=game.name or "Unknown Game",
                    image_url=image_url,
                    genres=genres,
                    platforms=platforms,
                    main_story=main_story,
                    main_story_with_extras=main_story_with_extras,
                    completionist=completionist,
                )
            )
        except httpx.HTTPError:
            logger.error("Error enriching game data", game_id=game.id)
    return results


async def search(
    search_term: str, client_id: str, client_secret: str, steamgriddb_api_key: str | None
) -> list[EnrichedResult]:
    """Enriched search: finds games on IGDB, then fills in cover image,
    genres, platforms and beat-time data (falling back to HowLongToBeat
    when IGDB has no beat-time data). Batches every lookup into at most
    one request per data type for the whole page of results - see
    issue #105. The raw IGDB search hits are resolved, deduped, filtered
    to drop anything DLC-like, and ranked by game type (main_game/
    remake/remaster/expanded_game first) before being truncated to
    _SEARCH_RESULT_LIMIT in _enrich_search_results - see issue #154,
    where DLC/alternate-version hits were crowding the base game out of
    the top results. `client_id`/`client_secret` are the caller's
    resolved IGDB credentials (their own, or the global settings
    fallback) - see routes/games.py::_resolve_igdb_credentials.
    `steamgriddb_api_key` is the calling user's resolved key (their own,
    or the global fallback) - see routes/games.py::_resolve_steamgriddb_api_key."""
    access_token = await get_valid_token(client_id, client_secret)
    search_results = await search_game_on_igdb(search_term, client_id, access_token)
    return await _enrich_search_results(
        search_results, client_id, access_token, search_term, steamgriddb_api_key
    )


def _normalize_game_title(title: str) -> str:
    return re.sub(r"[™®©]", "", title).strip().lower()


def _steam_app_list_is_fresh() -> bool:
    return (
        _steam_app_list_cached_at is not None
        and time.monotonic() - _steam_app_list_cached_at < _STEAM_APP_LIST_TTL_SECONDS
    )


def _steam_app_list_fetch_is_backed_off() -> bool:
    return (
        _steam_app_list_last_attempt_at is not None
        and time.monotonic() - _steam_app_list_last_attempt_at
        < _STEAM_APP_LIST_RETRY_BACKOFF_SECONDS
    )


async def _ensure_steam_app_list_cached() -> None:
    """Refreshes the title->Steam-App-ID lookup at most once per
    _STEAM_APP_LIST_TTL_SECONDS (Steam's full catalogue is hundreds of
    thousands of apps, too large to fetch per lookup). Concurrent
    callers coalesce onto a single in-flight fetch via the module lock
    rather than each starting their own; a fetch failure leaves the
    existing (possibly empty) cache in place and is retried no sooner
    than _STEAM_APP_LIST_RETRY_BACKOFF_SECONDS later, so a Steam outage
    can't turn every incoming lookup into its own failing fetch."""
    global _steam_app_list_cached_at, _steam_app_list_last_attempt_at
    if _steam_app_list_is_fresh():
        return

    async with _steam_app_list_lock:
        if _steam_app_list_is_fresh() or _steam_app_list_fetch_is_backed_off():
            return

        _steam_app_list_last_attempt_at = time.monotonic()
        try:
            apps = await get_steam_app_list()
        except httpx.HTTPError:
            logger.error("Failed to fetch Steam app list")
            return

        _steam_app_id_by_title.clear()
        for app in apps:
            _steam_app_id_by_title.setdefault(_normalize_game_title(app.name), app.appid)
        _steam_app_list_cached_at = time.monotonic()


async def find_steam_app_id(title: str) -> int | None:
    """Looks up a Steam App ID by exact (case/trademark-symbol
    insensitive) title match against Steam's public app catalogue -
    used to prefill the Steam App ID field when creating a backlog
    entry from an IGDB search result, since IGDB has no Steam App ID
    mapping of its own."""
    await _ensure_steam_app_list_cached()
    return _steam_app_id_by_title.get(_normalize_game_title(title))

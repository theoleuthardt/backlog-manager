import asyncio
import time
from collections.abc import Awaitable, Callable

import httpx
import structlog

from backlog_manager_backend.config import settings
from backlog_manager_backend.integrations.howlongtobeat import search_game_on_hltb
from backlog_manager_backend.integrations.igdb import (
    generate_igdb_token,
    get_cover_on_igdb,
    get_game_on_igdb,
    get_game_time_to_beat_on_igdb,
    get_genre_on_igdb,
    get_platform_on_igdb,
    search_game_on_igdb,
)
from backlog_manager_backend.integrations.types import (
    EnrichedResult,
    IGDBSearchResult,
)

logger = structlog.get_logger()

_SEARCH_RESULT_LIMIT = 8

_cached_token: dict[str, object] | None = None
_genre_cache: dict[int, str] = {}
_platform_cache: dict[int, str] = {}


async def get_valid_token() -> str:
    """Gets a valid IGDB access token, using the cached one if it hasn't
    expired yet (expires_in is in seconds; refreshed 5 minutes early)."""
    global _cached_token

    client_id = settings.igdb_client_id
    client_secret = settings.igdb_client_secret
    if not client_id or not client_secret:
        raise RuntimeError(
            "IGDB credentials not configured. Please set IGDB_CLIENT_ID and "
            "IGDB_CLIENT_SECRET environment variables."
        )

    if _cached_token is not None and _cached_token["expires_at"] > time.monotonic():
        return str(_cached_token["access_token"])

    token_response = await generate_igdb_token(client_id, client_secret)
    if not token_response.access_token:
        raise RuntimeError("Failed to generate IGDB access token")

    _cached_token = {
        "access_token": token_response.access_token,
        "expires_at": time.monotonic() + (token_response.expires_in - 300),
    }
    return token_response.access_token


async def get_cached_genre(genre_id: int, client_id: str, access_token: str) -> str | None:
    if genre_id in _genre_cache:
        return _genre_cache[genre_id]

    try:
        genre_data = await get_genre_on_igdb(genre_id, client_id, access_token)
        name = genre_data[0].name if genre_data else None
        if name:
            _genre_cache[genre_id] = name
            return name
    except httpx.HTTPError:
        logger.error("Failed to fetch genre", genre_id=genre_id)
    return None


async def get_cached_platform(platform_id: int, client_id: str, access_token: str) -> str | None:
    if platform_id in _platform_cache:
        return _platform_cache[platform_id]

    try:
        platform_data = await get_platform_on_igdb(platform_id, client_id, access_token)
        name = platform_data[0].name if platform_data else None
        if name:
            _platform_cache[platform_id] = name
            return name
    except httpx.HTTPError:
        logger.error("Failed to fetch platform", platform_id=platform_id)
    return None


async def process_in_batches[T, R](
    items: list[T],
    batch_size: int,
    processor: Callable[[T], Awaitable[R]],
    delay_between_batches_seconds: float = 1.0,
) -> list[R]:
    """Processes items with controlled concurrency to avoid IGDB rate
    limiting, waiting between batches."""
    results: list[R] = []
    for i in range(0, len(items), batch_size):
        batch = items[i : i + batch_size]
        results.extend(await asyncio.gather(*(processor(item) for item in batch)))
        if i + batch_size < len(items):
            await asyncio.sleep(delay_between_batches_seconds)
    return results


def _seconds_to_hours(seconds: int | None) -> float:
    return round((seconds / 3600) * 10) / 10 if seconds else 0.0


async def _enrich_search_result(
    search_result: IGDBSearchResult, client_id: str, access_token: str
) -> EnrichedResult | None:
    try:
        game_id = str(search_result.game if search_result.game is not None else search_result.id)
        game_data = await get_game_on_igdb(game_id, client_id, access_token)
        game = game_data[0] if game_data else None
        if game is None:
            return None

        image_url: str | None = None
        if game.cover:
            try:
                cover_data = await get_cover_on_igdb(game.cover, client_id, access_token)
                cover = cover_data[0] if cover_data else None
                if cover and cover.image_id:
                    image_url = (
                        "https://images.igdb.com/igdb/image/upload/"
                        f"t_cover_big/{cover.image_id}.jpg"
                    )
            except httpx.HTTPError:
                logger.error("Failed to fetch cover for game", game_id=game.id)

        genres: list[str] = []
        if game.genres:
            try:
                genre_names = await asyncio.gather(
                    *(
                        get_cached_genre(genre_id, client_id, access_token)
                        for genre_id in game.genres
                    )
                )
                genres = [name for name in genre_names if name is not None]
            except httpx.HTTPError:
                logger.error("Failed to fetch genres for game", game_id=game.id)

        platforms: list[str] = []
        if game.platforms:
            try:
                platform_names = await asyncio.gather(
                    *(
                        get_cached_platform(platform_id, client_id, access_token)
                        for platform_id in game.platforms
                    )
                )
                platforms = [name for name in platform_names if name is not None]
            except httpx.HTTPError:
                logger.error("Failed to fetch platforms for game", game_id=game.id)

        main_story = 0.0
        main_story_with_extras = 0.0
        completionist = 0.0
        try:
            time_to_beat_data = await get_game_time_to_beat_on_igdb(
                game.id, client_id, access_token
            )
            time_to_beat = time_to_beat_data[0] if time_to_beat_data else None
            if time_to_beat:
                main_story = _seconds_to_hours(time_to_beat.hastily)
                main_story_with_extras = _seconds_to_hours(time_to_beat.normally)
                completionist = _seconds_to_hours(time_to_beat.completely)
        except httpx.HTTPError:
            logger.error("Failed to fetch time to beat for game", game_id=game.id)

        hltb_id = game.id
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

        return EnrichedResult(
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
    except httpx.HTTPError:
        logger.error("Error enriching game data")
        return None


async def search(search_term: str) -> list[EnrichedResult]:
    """Enriched search: finds games on IGDB, then fills in cover image,
    genres, platforms and beat-time data (falling back to HowLongToBeat
    when IGDB has no beat-time data), one game at a time to respect
    IGDB's rate limits."""
    client_id = settings.igdb_client_id
    if not client_id:
        raise RuntimeError("IGDB_CLIENT_ID not configured")

    access_token = await get_valid_token()
    search_results = await search_game_on_igdb(search_term, client_id, access_token)
    games_to_process = search_results[:_SEARCH_RESULT_LIMIT]

    enriched_results = await process_in_batches(
        games_to_process,
        1,
        lambda result: _enrich_search_result(result, client_id, access_token),
    )
    return [result for result in enriched_results if result is not None]

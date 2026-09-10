from collections.abc import Awaitable, Callable
from decimal import ROUND_HALF_UP, Decimal

import httpx
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.integrations.howlongtobeat import search_game_on_hltb
from backlog_manager_backend.integrations.steam import (
    get_achievement_schema,
    get_owned_games,
    get_player_achievements,
)
from backlog_manager_backend.integrations.types import (
    AchievementInfo,
    AchievementProgress,
    SteamAchievementSchema,
    SteamOwnedGame,
)
from backlog_manager_backend.repositories import backlog_entry_repo
from backlog_manager_backend.schemas.backlog_entry import (
    BacklogEntry,
    CreateBacklogEntryParams,
    UpdateBacklogEntryParams,
)
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import game_service

logger = structlog.get_logger()

ProgressCallback = Callable[[int, int], Awaitable[None]]

_MINUTES_PER_HOUR = Decimal(60)
_IMPORTED_PLATFORM = "PC"
_IMPORTED_STATUS = "Not Started"
_IMPORTED_INTEREST = 5
_STEAM_NOT_LINKED = "Steam account is not linked"

_ACHIEVEMENT_SCHEMA_CACHE_MAX_SIZE = 500
_achievement_schema_cache: dict[int, list[SteamAchievementSchema]] = {}


def _minutes_to_hours(minutes: int) -> Decimal:
    return (Decimal(minutes) / _MINUTES_PER_HOUR).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


async def sync_playtimes(
    session: AsyncSession,
    user: User,
    api_key: str,
    owned_games: list[SteamOwnedGame] | None = None,
) -> list[BacklogEntry]:
    """Matches the user's backlog entries to their Steam library by
    steam_app_id and overwrites playtime with Steam's authoritative
    value, converted from minutes to hours. Entries with no linked
    steam_app_id, or whose app isn't in the Steam response, are left
    untouched rather than cleared.

    Accepts an already-fetched owned_games snapshot so callers that
    also run import_library (see sync_playtimes_and_import) hit Steam's
    API once instead of twice with two potentially inconsistent
    snapshots; fetches its own when called standalone."""
    if not user.steam_id:
        raise ValidationError(_STEAM_NOT_LINKED)
    if owned_games is None:
        owned_games = await get_owned_games(user.steam_id, api_key)

    owned_by_app_id = {game.appid: game for game in owned_games}

    updated: list[BacklogEntry] = []
    for entry in await backlog_entry_repo.get_backlog_entries_by_user(session, user.id):
        if entry.steam_app_id is None:
            continue
        owned_game = owned_by_app_id.get(entry.steam_app_id)
        if owned_game is None:
            continue
        playtime = _minutes_to_hours(owned_game.playtime_forever)
        if entry.playtime == playtime:
            continue
        updated.append(
            await backlog_entry_repo.update_backlog_entry(
                session,
                UpdateBacklogEntryParams(backlog_entry_id=entry.backlog_entry_id, playtime=playtime),
            )
        )
    return updated


async def _try_get_cover(steam_app_id: int, steamgriddb_api_key: str | None) -> str | None:
    """Best-effort SteamGridDB cover lookup for one freshly-imported
    game - a missing key, outage, or no-covers-available result must
    not fail the import, it should just leave that entry without a
    cover, the same as a manually-created entry."""
    if not steamgriddb_api_key:
        return None
    try:
        covers = await game_service.get_game_covers(steam_app_id, steamgriddb_api_key)
    except (RuntimeError, httpx.HTTPError):
        return None
    return covers[0] if covers else None


async def _try_get_hltb_times(title: str) -> tuple[Decimal | None, Decimal | None, Decimal | None]:
    """Best-effort HowLongToBeat lookup for one freshly-imported game,
    by title (HLTB has no Steam App ID lookup) - search_game_on_hltb
    already returns [] rather than raising on failure, so there's
    nothing to catch here, just a possible empty match."""
    results = await search_game_on_hltb(title)
    if not results:
        return None, None, None
    match = results[0]
    return (
        Decimal(str(match.main_story)),
        Decimal(str(match.main_story_with_extras)),
        Decimal(str(match.completionist)),
    )


async def _merge_family_games(
    owned_games: list[SteamOwnedGame], family_steam_ids: list[str], api_key: str
) -> list[SteamOwnedGame]:
    """Adds games owned by Steam Family members that aren't already in
    the user's own library, for import_library's family_steam_ids
    support. Family-only games get playtime_forever=0 - GetOwnedGames
    reports the *family member's* playtime for their own steamid, not
    the current user's, so carrying it over would misrepresent it as
    the current user's played time. A family member whose GetOwnedGames
    call fails (private profile, bad ID, Steam outage) is skipped
    rather than failing the whole import."""
    merged = list(owned_games)
    seen_appids = {game.appid for game in owned_games}
    for family_steam_id in family_steam_ids:
        try:
            family_games = await get_owned_games(family_steam_id, api_key)
        except httpx.HTTPError:
            logger.warning(
                "Failed to fetch Steam family member's library, skipping",
                steam_id=family_steam_id,
            )
            continue
        for game in family_games:
            if game.appid in seen_appids:
                continue
            seen_appids.add(game.appid)
            merged.append(SteamOwnedGame(appid=game.appid, name=game.name, playtime_forever=0))
    return merged


async def import_library(
    session: AsyncSession,
    user: User,
    api_key: str,
    owned_games: list[SteamOwnedGame] | None = None,
    steamgriddb_api_key: str | None = None,
    on_progress: ProgressCallback | None = None,
    family_steam_ids: list[str] | None = None,
) -> list[BacklogEntry]:
    """Creates a backlog entry for every Steam-owned game not already
    linked to one by steam_app_id. Metadata beyond title/steam_app_id/
    playtime is deliberately minimal (no IGDB enrichment, no genre); a
    user can fill in genre etc. by hand afterwards. `steamgriddb_api_key`,
    when the caller has one (their own, or the global fallback), fills
    in a cover image per game too - best-effort, see _try_get_cover. A
    HowLongToBeat time-to-beat lookup by title also runs for every
    game unconditionally (no key needed) - best-effort, see
    _try_get_hltb_times.

    The existing-entries check above only prevents most duplicates - a
    concurrent import for the same user can still race past it, so the
    database's unique constraint on (user_id, steam_app_id) is the
    actual guarantee; a ConflictError from that constraint is treated
    as "already imported" and skipped rather than failing the import.

    Every other exception raised while creating one entry is also
    caught, rolled back, and logged rather than left to propagate -
    see issue #154: each entry is committed individually, so one game
    failing partway through a large library (a decode quirk, an
    unmapped database error, ...) must not silently discard every game
    after it while leaving the earlier ones committed. The rollback
    matters even when nothing else in the loop touches the session
    directly: a failed commit can leave the session's transaction
    unusable, which would otherwise make every subsequent create in
    this same loop fail too.

    Accepts an already-fetched owned_games snapshot - see
    sync_playtimes's docstring for why - and merges in each
    family_steam_ids member's library (Steam Family sharing) via
    _merge_family_games before the import loop runs, so those games get
    imported the same way. `on_progress`, when given, is awaited after
    every game considered (whether it was actually imported, already
    existed, or failed), so callers can report "N of total processed"
    even on a re-sync where most games are skipped as already-imported."""
    if not user.steam_id:
        raise ValidationError(_STEAM_NOT_LINKED)
    if owned_games is None:
        owned_games = await get_owned_games(user.steam_id, api_key)

    games_to_import = owned_games
    if family_steam_ids:
        games_to_import = await _merge_family_games(owned_games, family_steam_ids, api_key)

    existing_app_ids = {
        entry.steam_app_id
        for entry in await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
        if entry.steam_app_id is not None
    }

    created: list[BacklogEntry] = []
    total = len(games_to_import)
    for processed, game in enumerate(games_to_import, start=1):
        if game.appid in existing_app_ids:
            if on_progress:
                await on_progress(processed, total)
            continue
        try:
            image_link = await _try_get_cover(game.appid, steamgriddb_api_key)
            main_time, main_plus_extra_time, completion_time = await _try_get_hltb_times(
                game.name
            )
            created.append(
                await backlog_entry_repo.create_backlog_entry(
                    session,
                    CreateBacklogEntryParams(
                        user_id=user.id,
                        title=game.name,
                        genre="",
                        platform=_IMPORTED_PLATFORM,
                        status=_IMPORTED_STATUS,
                        owned=True,
                        interest=_IMPORTED_INTEREST,
                        playtime=_minutes_to_hours(game.playtime_forever),
                        steam_app_id=game.appid,
                        image_link=image_link,
                        main_time=main_time,
                        main_plus_extra_time=main_plus_extra_time,
                        completion_time=completion_time,
                    ),
                )
            )
        except ConflictError:
            continue
        except Exception:
            await session.rollback()
            logger.exception(
                "Failed to import Steam-owned game into backlog",
                steam_app_id=game.appid,
                title=game.name,
            )
            continue
        finally:
            if on_progress:
                await on_progress(processed, total)
    return created


async def sync_playtimes_and_import(
    session: AsyncSession,
    user: User,
    api_key: str,
    *,
    auto_import: bool,
    steamgriddb_api_key: str | None = None,
    on_progress: ProgressCallback | None = None,
    family_steam_ids: list[str] | None = None,
) -> list[BacklogEntry]:
    """Single entry point for the "Sync Steam Playtimes" action: fetches
    the owned-games snapshot once and reuses it for both sync_playtimes
    and (when auto_import is on) import_library, instead of each
    fetching its own snapshot from Steam's API. `on_progress` is only
    ever driven by import_library - sync_playtimes has no per-game
    external API calls, so it finishes near-instantly and isn't worth
    reporting progress for. `family_steam_ids` only affects
    import_library too - sync_playtimes only ever updates entries
    already linked to the user's own steam_app_id, and family members'
    playtime isn't the user's own (see _merge_family_games)."""
    if not user.steam_id:
        raise ValidationError(_STEAM_NOT_LINKED)
    owned_games = await get_owned_games(user.steam_id, api_key)

    updated = await sync_playtimes(session, user, api_key, owned_games)
    if auto_import:
        updated = updated + await import_library(
            session,
            user,
            api_key,
            owned_games,
            steamgriddb_api_key=steamgriddb_api_key,
            on_progress=on_progress,
            family_steam_ids=family_steam_ids,
        )
    return updated


async def _get_achievement_schema_cached(
    steam_app_id: int, api_key: str
) -> list[SteamAchievementSchema]:
    """Best-effort: a SteamGridDB-style outage here must not fail the
    whole achievements request, since the schema only supplies display
    name/description/icon polish - get_player_achievements already
    returns usable name/description on its own (see
    get_achievement_progress). The cache is bounded to
    _ACHIEVEMENT_SCHEMA_CACHE_MAX_SIZE entries, like
    game_service._steamgriddb_cover_cache, since steam_app_id here is
    also a caller-supplied query param rather than something only ever
    sourced from Steam's own catalogue."""
    if steam_app_id in _achievement_schema_cache:
        return _achievement_schema_cache[steam_app_id]

    try:
        schema = await get_achievement_schema(steam_app_id, api_key)
    except httpx.HTTPError:
        return []

    if len(_achievement_schema_cache) >= _ACHIEVEMENT_SCHEMA_CACHE_MAX_SIZE:
        _achievement_schema_cache.pop(next(iter(_achievement_schema_cache)))
    _achievement_schema_cache[steam_app_id] = schema
    return schema


async def get_achievement_progress(
    user: User, api_key: str, steam_app_id: int
) -> AchievementProgress:
    """Combines GetPlayerAchievements (per-user achieved status) with
    GetSchemaForGame (static per-game display name/description/icon)
    into one payload, powering the achievement progress bar and
    overview in the Creation Tool and Update Dialog - see issue #73.
    playerstats.success being false (app has no stats, or the
    profile/game isn't public) yields an empty result rather than an
    error - there's simply no achievement data to show."""
    if not user.steam_id:
        raise ValidationError(_STEAM_NOT_LINKED)

    player_stats = await get_player_achievements(user.steam_id, steam_app_id, api_key)
    if not player_stats.success or not player_stats.achievements:
        return AchievementProgress(unlocked=0, total=0, achievements=[])

    schema_by_apiname = {
        entry.name: entry
        for entry in await _get_achievement_schema_cached(steam_app_id, api_key)
    }

    achievements = [
        AchievementInfo(
            apiname=achievement.apiname,
            display_name=schema.display_name if schema else (achievement.name or achievement.apiname),
            description=schema.description if schema else achievement.description,
            icon=schema.icon if schema else None,
            achieved=bool(achievement.achieved),
            unlock_time=achievement.unlocktime,
            hidden=bool(schema.hidden) if schema else False,
        )
        for achievement in player_stats.achievements
        for schema in (schema_by_apiname.get(achievement.apiname),)
    ]
    unlocked = sum(1 for achievement in achievements if achievement.achieved)
    return AchievementProgress(unlocked=unlocked, total=len(achievements), achievements=achievements)

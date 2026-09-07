from decimal import ROUND_HALF_UP, Decimal

import httpx
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, ValidationError
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

logger = structlog.get_logger()

_MINUTES_PER_HOUR = Decimal(60)
_IMPORTED_PLATFORM = "PC"
_IMPORTED_STATUS = "Not Started"
_IMPORTED_INTEREST = 5
_STEAM_NOT_LINKED = "Steam account is not linked"

# Bounded like game_service._steamgriddb_cover_cache - app_id here is
# also a caller-supplied query param, not something only ever sourced
# from Steam's own catalogue.
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


async def import_library(
    session: AsyncSession,
    user: User,
    api_key: str,
    owned_games: list[SteamOwnedGame] | None = None,
) -> list[BacklogEntry]:
    """Creates a backlog entry for every Steam-owned game not already
    linked to one by steam_app_id. Metadata beyond title/steam_app_id/
    playtime is deliberately minimal (no IGDB/HLTB enrichment); a user
    can fill in genre etc. by hand afterwards.

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
    sync_playtimes's docstring for why."""
    if not user.steam_id:
        raise ValidationError(_STEAM_NOT_LINKED)
    if owned_games is None:
        owned_games = await get_owned_games(user.steam_id, api_key)

    existing_app_ids = {
        entry.steam_app_id
        for entry in await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
        if entry.steam_app_id is not None
    }

    created: list[BacklogEntry] = []
    for game in owned_games:
        if game.appid in existing_app_ids:
            continue
        try:
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
    return created


async def sync_playtimes_and_import(
    session: AsyncSession, user: User, api_key: str, *, auto_import: bool
) -> list[BacklogEntry]:
    """Single entry point for the "Sync Steam Playtimes" action: fetches
    the owned-games snapshot once and reuses it for both sync_playtimes
    and (when auto_import is on) import_library, instead of each
    fetching its own snapshot from Steam's API."""
    if not user.steam_id:
        raise ValidationError(_STEAM_NOT_LINKED)
    owned_games = await get_owned_games(user.steam_id, api_key)

    updated = await sync_playtimes(session, user, api_key, owned_games)
    if auto_import:
        updated = updated + await import_library(session, user, api_key, owned_games)
    return updated


async def _get_achievement_schema_cached(
    steam_app_id: int, api_key: str
) -> list[SteamAchievementSchema]:
    """Best-effort: a SteamGridDB-style outage here must not fail the
    whole achievements request, since the schema only supplies display
    name/description/icon polish - get_player_achievements already
    returns usable name/description on its own (see
    get_achievement_progress)."""
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
        )
        for achievement in player_stats.achievements
        for schema in (schema_by_apiname.get(achievement.apiname),)
    ]
    unlocked = sum(1 for achievement in achievements if achievement.achieved)
    return AchievementProgress(unlocked=unlocked, total=len(achievements), achievements=achievements)

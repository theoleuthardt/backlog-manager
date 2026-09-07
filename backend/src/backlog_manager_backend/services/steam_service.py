from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.integrations.steam import get_owned_games
from backlog_manager_backend.repositories import backlog_entry_repo
from backlog_manager_backend.schemas.backlog_entry import BacklogEntry, UpdateBacklogEntryParams
from backlog_manager_backend.schemas.user import User

_MINUTES_PER_HOUR = Decimal(60)


def _minutes_to_hours(minutes: int) -> Decimal:
    return (Decimal(minutes) / _MINUTES_PER_HOUR).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


async def sync_playtimes(session: AsyncSession, user: User, api_key: str) -> list[BacklogEntry]:
    """Matches the user's backlog entries to their Steam library by
    steam_app_id (currently only set by manual entry - see
    CreationToolForm/BacklogEntry.tsx - until a full automatic library
    sync exists) and overwrites playtime with Steam's authoritative
    value, converted from minutes to hours. Entries with no linked
    steam_app_id, or whose app isn't in the Steam response, are left
    untouched rather than cleared."""
    if not user.steam_id:
        raise ValidationError("Steam account is not linked")

    owned_by_app_id = {game.appid: game for game in await get_owned_games(user.steam_id, api_key)}

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

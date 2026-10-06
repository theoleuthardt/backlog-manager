"""Retroactive IGDB enrichment of existing personal entries - the "sync
IGDB game data" action next to the Steam playtime sync."""

import asyncio

import msgspec
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.integrations.types import EnrichedResult
from backlog_manager_backend.repositories import backlog_entry_repo
from backlog_manager_backend.schemas.backlog_entry import BacklogEntry, UpdateBacklogEntryParams
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import game_service
from backlog_manager_backend.services.steam_service import ProgressCallback

_LOOKUP_CONCURRENCY = 4


def _missing_igdb_data(entry: BacklogEntry) -> bool:
    return not entry.genre.strip() or entry.description is None or entry.publisher is None


def _has_dirty_steam_title(entry: BacklogEntry) -> bool:
    return entry.steam_app_id is not None and entry.title != game_service.clean_game_title(
        entry.title
    )


def _needs_sync(entry: BacklogEntry) -> bool:
    return _missing_igdb_data(entry) or _has_dirty_steam_title(entry)


def _build_update(entry: BacklogEntry, match: EnrichedResult | None) -> UpdateBacklogEntryParams:
    """Only fills what the entry is missing - values the user typed or an
    earlier sync stored are never overwritten. Steam-linked entries also
    get their title cleaned of trademark symbols (see
    game_service.clean_game_title), since imports used to keep them."""
    changes: dict[str, object] = {}
    cleaned_title = game_service.clean_game_title(entry.title)
    if entry.steam_app_id is not None and cleaned_title != entry.title:
        changes["title"] = cleaned_title
    if match is not None:
        if not entry.genre.strip() and match.genres:
            changes["genre"] = ", ".join(match.genres)
        if entry.description is None and match.description:
            changes["description"] = match.description
        if entry.trailer_link is None and match.trailer_url:
            changes["trailer_link"] = match.trailer_url
        if entry.publisher is None and match.publisher:
            changes["publisher"] = match.publisher
        times = game_service.igdb_times(match)
        no_times_yet = (
            entry.main_time is None
            and entry.main_plus_extra_time is None
            and entry.completion_time is None
        )
        if times and no_times_yet:
            changes["main_time"] = times[0]
            changes["main_plus_extra_time"] = times[1]
            changes["completion_time"] = times[2]
    return UpdateBacklogEntryParams(backlog_entry_id=entry.backlog_entry_id, **changes)


async def count_entries_needing_sync(session: AsyncSession, user_id: int) -> int:
    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user_id)
    return sum(1 for entry in entries if _needs_sync(entry))


async def sync_igdb_data(
    session: AsyncSession,
    user: User,
    igdb_credentials: tuple[str, str],
    on_progress: ProgressCallback | None = None,
) -> list[BacklogEntry]:
    """Looks up the top IGDB match for every personal entry that lacks a
    genre, description or publisher (or carries trademark symbols in its title) and
    fills in what is missing, returning the entries that changed.
    Lookups run concurrently (bounded by _LOOKUP_CONCURRENCY) and report
    progress as each finishes; the DB writes that follow are serial,
    since one AsyncSession is not safe across coroutines. An entry whose
    lookup fails or finds nothing is left as it was."""
    candidates = [
        entry
        for entry in await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
        if _needs_sync(entry)
    ]
    semaphore = asyncio.Semaphore(_LOOKUP_CONCURRENCY)
    processed = 0

    async def look_up(entry: BacklogEntry) -> EnrichedResult | None:
        nonlocal processed
        match = None
        if _missing_igdb_data(entry):
            async with semaphore:
                match = await game_service.find_igdb_match(
                    game_service.clean_game_title(entry.title),
                    igdb_credentials,
                    include_publisher=True,
                )
        processed += 1
        if on_progress:
            await on_progress(processed, len(candidates))
        return match

    matches = await asyncio.gather(*(look_up(entry) for entry in candidates))

    updated: list[BacklogEntry] = []
    for entry, match in zip(candidates, matches, strict=True):
        params = _build_update(entry, match)
        if any(
            getattr(params, field) is not msgspec.UNSET
            for field in params.__struct_fields__
            if field != "backlog_entry_id"
        ):
            updated.append(await backlog_entry_repo.update_backlog_entry(session, params))
    return updated

"""Automatic Steam wishlist sync: for users who switched it on after their
first wishlist import, a scheduler calls `sync_all` every hour. Games that
joined the wishlist are added as wishlist imports, wishlist-imported games
that left it are removed, and everything is collected in the user's
`SteamWishlistSyncReport` until they dismiss it (the diff popup shown at the
next login)."""

from collections.abc import Callable
from datetime import UTC, datetime

import msgspec
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import UpdateBacklogEntryParams
from backlog_manager_backend.schemas.steam_wishlist_sync import (
    SteamWishlistChange,
    SteamWishlistSyncReport,
)
from backlog_manager_backend.schemas.user import UpdateUserParams, User
from backlog_manager_backend.services import steam_service

logger = structlog.get_logger()

_NOT_OWNED_STATUS = "Not Owned"


class SyncResult(msgspec.Struct):
    added: int = 0
    removed: int = 0


class SyncSummary(msgspec.Struct):
    users: int = 0
    added: int = 0
    removed: int = 0
    failed: int = 0


def merge_report(
    report: SteamWishlistSyncReport | None,
    added: list[SteamWishlistChange],
    removed: list[SteamWishlistChange],
    now: datetime,
) -> SteamWishlistSyncReport | None:
    """Folds one run's changes into the pending report: a game added after
    it was reported removed (or the other way round) cancels out, so the
    report only holds the net difference since the user last looked.
    Returns None while nothing is left to report."""
    current_added = list(report.added) if report else []
    current_removed = list(report.removed) if report else []
    for change in added:
        if any(c.steam_app_id == change.steam_app_id for c in current_removed):
            current_removed = [c for c in current_removed if c.steam_app_id != change.steam_app_id]
        else:
            current_added.append(change)
    for change in removed:
        if any(c.steam_app_id == change.steam_app_id for c in current_added):
            current_added = [c for c in current_added if c.steam_app_id != change.steam_app_id]
        else:
            current_removed.append(change)
    if not current_added and not current_removed:
        return None
    since = report.since if report and report.since else now
    return SteamWishlistSyncReport(since=since, added=current_added, removed=current_removed)


async def sync_user(
    session: AsyncSession,
    user: User,
    steamgriddb_api_key: str | None = None,
    igdb_credentials: tuple[str, str] | None = None,
) -> SyncResult:
    """Brings the user's wishlist-imported entries in line with their Steam
    wishlist. An empty wishlist is treated as unreadable (a private profile
    answers with an empty list) and changes nothing. A wishlist import the
    user has worked with (owned, or moved out of "Not Owned") is never
    deleted, only released from the sync."""
    if not user.steam_id:
        return SyncResult()
    wishlist = await steam_service.get_wishlist(user.steam_id)

    await steam_service.repair_steam_titles(session, user, steamgriddb_api_key, igdb_credentials)

    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    tracked = [entry for entry in entries if entry.steam_wishlist_import]
    if not wishlist:
        return SyncResult()

    wishlist_ids = {item.appid for item in wishlist}
    existing_ids = {entry.steam_app_id for entry in entries if entry.steam_app_id is not None}

    removed: list[SteamWishlistChange] = []
    for entry in tracked:
        if entry.steam_app_id in wishlist_ids:
            continue
        if entry.owned or entry.status != _NOT_OWNED_STATUS:
            await backlog_entry_repo.update_backlog_entry(
                session,
                UpdateBacklogEntryParams(
                    backlog_entry_id=entry.backlog_entry_id, steam_wishlist_import=False
                ),
            )
            continue
        await backlog_entry_repo.delete_backlog_entry(session, entry.backlog_entry_id)
        removed.append(
            SteamWishlistChange(
                steam_app_id=entry.steam_app_id or 0,
                title=entry.title,
                image_link=entry.image_link,
            )
        )

    missing = [item for item in wishlist if item.appid not in existing_ids]
    created = (
        await steam_service.import_wishlist(
            session,
            user,
            missing,
            steamgriddb_api_key,
            igdb_credentials=igdb_credentials,
        )
        if missing
        else []
    )
    added = [
        SteamWishlistChange(
            steam_app_id=entry.steam_app_id or 0, title=entry.title, image_link=entry.image_link
        )
        for entry in created
    ]

    if added or removed:
        fresh = await user_repo.get_user_by_id(session, user.id)
        await user_repo.update_user(
            session,
            UpdateUserParams(
                user_id=user.id,
                steam_wishlist_sync_report=merge_report(
                    fresh.steam_wishlist_sync_report, added, removed, datetime.now(UTC)
                ),
            ),
        )
    return SyncResult(added=len(added), removed=len(removed))


async def sync_all(
    session: AsyncSession,
    credentials_for: Callable[[User], tuple[str | None, tuple[str, str] | None]] = lambda _: (
        None,
        None,
    ),
) -> SyncSummary:
    """Runs `sync_user` for everyone who opted in and has done the first
    wishlist import; `credentials_for` yields a user's SteamGridDB key and
    IGDB credentials. One user's failure is logged and does not stop the
    others."""
    summary = SyncSummary()
    for user in await user_repo.get_all_users(session):
        if (
            not user.steam_wishlist_auto_sync
            or not user.steam_id
            or user.steam_wishlist_imported_at is None
        ):
            continue
        try:
            steamgriddb_api_key, igdb_credentials = credentials_for(user)
            result = await sync_user(session, user, steamgriddb_api_key, igdb_credentials)
        except Exception:
            await session.rollback()
            summary.failed += 1
            logger.exception("Steam wishlist auto sync failed", user_id=user.id)
            continue
        summary.users += 1
        summary.added += result.added
        summary.removed += result.removed
    return summary

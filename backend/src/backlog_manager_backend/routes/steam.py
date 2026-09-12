import asyncio
from collections.abc import AsyncIterator, Awaitable, Callable

import httpx
import msgspec
from cryptography.fernet import InvalidToken
from litestar import Router, get, post
from litestar.datastructures import CacheControlHeader
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, ServiceUnavailableException
from litestar.params import FromQuery
from litestar.response import ServerSentEvent, ServerSentEventMessage
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.auth.encryption import decrypt
from backlog_manager_backend.config import settings
from backlog_manager_backend.db import async_session
from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.integrations.types import AchievementProgress, SteamWishlistItem
from backlog_manager_backend.schemas.backlog_entry import BacklogEntry, BacklogEntryResponse
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import steam_service

_STEAM_NOT_CONFIGURED = "Steam Web API integration is not configured"
_STEAM_UNAVAILABLE = "Steam Web API is currently unreachable"
_NO_STORE = CacheControlHeader(no_store=True)
_SSE_DONE = "done"
_SSE_ERROR = "error"
_SSE_PROGRESS = "progress"
_WISHLIST_IMPORT_MAX_ITEMS = 10_000


def _resolve_api_key(user: User) -> str:
    if user.steam_api_key_encrypted and settings.steam_api_key_encryption_key:
        try:
            return decrypt(user.steam_api_key_encrypted, settings.steam_api_key_encryption_key)
        except (InvalidToken, ValueError) as error:
            raise ServiceUnavailableException(_STEAM_UNAVAILABLE) from error
    if settings.steam_web_api_key:
        return settings.steam_web_api_key
    raise ServiceUnavailableException(_STEAM_NOT_CONFIGURED)


def _resolve_steamgriddb_api_key(user: User) -> str | None:
    """Mirrors routes/games.py::_resolve_steamgriddb_api_key - a missing
    key here resolves to None rather than raising, since import_library
    already treats "no key" as a legitimate, non-fatal state (skip
    cover lookup, import the game anyway)."""
    if user.steamgriddb_api_key_encrypted and settings.steam_api_key_encryption_key:
        try:
            return decrypt(
                user.steamgriddb_api_key_encrypted, settings.steam_api_key_encryption_key
            )
        except (InvalidToken, ValueError):
            return None
    return settings.steamgriddb_api_key


def _resolve_family_steam_ids(user: User) -> list[str]:
    """Steam Family sharing support: steam_family_ids is a plain
    comma-separated list of the other members' SteamID64s (mirroring
    how genre/platform are stored on a backlog entry) - no separate
    table, since these IDs don't need anything beyond the string
    itself. Deduplicated and order-preserving so a repeated ID doesn't
    fetch that member's library twice."""
    if not user.steam_family_ids:
        return []
    seen: set[str] = set()
    family_ids: list[str] = []
    for raw_id in user.steam_family_ids.split(","):
        steam_id = raw_id.strip()
        if steam_id and steam_id not in seen:
            seen.add(steam_id)
            family_ids.append(steam_id)
    return family_ids


_user_operation_locks: dict[int, asyncio.Lock] = {}


def _get_user_operation_lock(user_id: int) -> asyncio.Lock:
    lock = _user_operation_locks.get(user_id)
    if lock is None:
        lock = asyncio.Lock()
        _user_operation_locks[user_id] = lock
    return lock


def _validate_wishlist_items(items: list[SteamWishlistItem]) -> None:
    """Route-boundary validation of the POSTed wishlist: appids below 1
    can never match a real Steam app, and an unbounded list would turn
    into an unbounded per-item lookup-and-write loop. Runs before the
    SSE stream opens so rejections surface as a plain 400, not an
    in-stream error event."""
    if len(items) > _WISHLIST_IMPORT_MAX_ITEMS:
        raise ClientException(
            f"Wishlist import is limited to {_WISHLIST_IMPORT_MAX_ITEMS} items"
        )
    for item in items:
        if item.appid < 1:
            raise ClientException("steam app ids must be 1 or greater")


async def _stream_steam_operation(
    run: Callable[[steam_service.ProgressCallback], Awaitable[list[BacklogEntry]]],
) -> AsyncIterator[ServerSentEventMessage]:
    """Bridges a steam_service call (which reports progress via a plain
    async callback, not a generator, since it also needs to return the
    final entry list) onto an SSE stream: `run` executes in a background
    task and pushes progress/done/error messages onto a queue, which
    this generator drains and yields as they arrive. Draining via a
    queue (rather than yielding straight from on_progress) lets `run`
    keep its normal call/return shape instead of needing to become a
    generator itself.

    `run` must open and close its own db session (e.g. via
    `async with async_session() as db_session`) rather than taking one
    as a NamedDependency - Litestar closes a streaming handler's
    dependencies as soon as the handler *returns the response object*,
    which happens before this generator (and therefore `run`) ever
    executes, not after the stream finishes."""
    def encode_result(entries: list[BacklogEntry]) -> str:
        return msgspec.json.encode(
            [BacklogEntryResponse.from_entry(entry) for entry in entries]
        ).decode()

    async for message in _stream_steam_messages(run, encode_result):
        yield message


async def _stream_steam_messages[T](
    run: Callable[[steam_service.ProgressCallback], Awaitable[list[T]]],
    encode_result: Callable[[list[T]], str],
) -> AsyncIterator[ServerSentEventMessage]:
    """_stream_steam_operation without the BacklogEntryResponse mapping,
    for calls that return msgspec-encodable payloads directly (e.g. the
    preview endpoints' SteamPreviewItem lists). Generic over the result
    item type so typed callers don't need a cast."""
    queue: asyncio.Queue[ServerSentEventMessage | None] = asyncio.Queue()

    async def on_progress(processed: int, total: int) -> None:
        await queue.put(
            ServerSentEventMessage(
                event=_SSE_PROGRESS,
                data=msgspec.json.encode({"processed": processed, "total": total}).decode(),
            )
        )

    async def run_operation() -> None:
        try:
            result = await run(on_progress)
            await queue.put(
                ServerSentEventMessage(event=_SSE_DONE, data=encode_result(result))
            )
        except ValidationError as error:
            await queue.put(ServerSentEventMessage(event=_SSE_ERROR, data=str(error)))
        except httpx.HTTPError:
            await queue.put(ServerSentEventMessage(event=_SSE_ERROR, data=_STEAM_UNAVAILABLE))
        finally:
            await queue.put(None)

    task = asyncio.create_task(run_operation())
    try:
        while (message := await queue.get()) is not None:
            yield message
    finally:
        await task


@post("/api/user/steam/sync", status_code=200)
async def sync_steam_playtimes(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> list[BacklogEntryResponse]:
    api_key = _resolve_api_key(current_user)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)

    try:
        updated = await steam_service.sync_playtimes_and_import(
            db_session,
            current_user,
            api_key,
            auto_import=current_user.steam_auto_import_enabled,
            steamgriddb_api_key=steamgriddb_api_key,
            family_steam_ids=_resolve_family_steam_ids(current_user),
        )
    except ValidationError as error:
        raise ClientException(str(error)) from error
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_STEAM_UNAVAILABLE) from error

    return [BacklogEntryResponse.from_entry(entry) for entry in updated]


@post("/api/user/steam/import", status_code=200)
async def import_steam_library(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> list[BacklogEntryResponse]:
    api_key = _resolve_api_key(current_user)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)

    try:
        created = await steam_service.import_library(
            db_session,
            current_user,
            api_key,
            steamgriddb_api_key=steamgriddb_api_key,
            family_steam_ids=_resolve_family_steam_ids(current_user),
        )
    except ValidationError as error:
        raise ClientException(str(error)) from error
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_STEAM_UNAVAILABLE) from error

    return [BacklogEntryResponse.from_entry(entry) for entry in created]


@post("/api/user/steam/sync/stream", status_code=200, media_type="text/event-stream")
async def sync_steam_playtimes_stream(
    current_user: NamedDependency[User],
) -> ServerSentEvent:
    """SSE variant of sync_steam_playtimes: emits a `progress` event
    after every game considered during the auto-import pass (see
    steam_service.import_library's on_progress), then a final `done`
    event carrying the same payload sync_steam_playtimes returns
    directly, or an `error` event in place of the raised exception."""
    api_key = _resolve_api_key(current_user)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)
    family_steam_ids = _resolve_family_steam_ids(current_user)
    operation_lock = _get_user_operation_lock(current_user.id)

    async def run(on_progress: steam_service.ProgressCallback) -> list[BacklogEntry]:
        async with operation_lock, async_session() as db_session:
            return await steam_service.sync_playtimes_and_import(
                db_session,
                current_user,
                api_key,
                auto_import=current_user.steam_auto_import_enabled,
                steamgriddb_api_key=steamgriddb_api_key,
                on_progress=on_progress,
                family_steam_ids=family_steam_ids,
            )

    return ServerSentEvent(_stream_steam_operation(run))


@post("/api/user/steam/import/stream", status_code=200, media_type="text/event-stream")
async def import_steam_library_stream(
    data: list[SteamWishlistItem] | None = None,
    current_user: NamedDependency[User] = None,  # type: ignore[assignment]
) -> ServerSentEvent:
    """SSE variant of import_steam_library - see
    sync_steam_playtimes_stream's docstring. Accepts the steam app ids
    the user confirmed in the preview as an optional JSON body
    (`[{"appid": 620}]`); when given, the import is restricted to those
    games so it always matches what was previewed - anything that left
    the Steam library or entered the backlog since the preview is
    ignored rather than silently imported."""
    api_key = _resolve_api_key(current_user)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)
    family_steam_ids = _resolve_family_steam_ids(current_user)
    confirmed_app_ids = [item.appid for item in data] if data else None
    if confirmed_app_ids is not None:
        _validate_wishlist_items(data)

    operation_lock = _get_user_operation_lock(current_user.id)

    async def run(on_progress: steam_service.ProgressCallback) -> list[BacklogEntry]:
        async with operation_lock, async_session() as db_session:
            return await steam_service.import_library(
                db_session,
                current_user,
                api_key,
                steamgriddb_api_key=steamgriddb_api_key,
                on_progress=on_progress,
                family_steam_ids=family_steam_ids,
                confirmed_app_ids=confirmed_app_ids,
            )

    return ServerSentEvent(_stream_steam_operation(run))


@get("/api/user/steam/achievements")
async def get_steam_achievements(
    steam_app_id: FromQuery[int],
    current_user: NamedDependency[User],
) -> AchievementProgress:
    api_key = _resolve_api_key(current_user)

    try:
        return await steam_service.get_achievement_progress(current_user, api_key, steam_app_id)
    except ValidationError as error:
        raise ClientException(str(error)) from error
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_STEAM_UNAVAILABLE) from error


@get("/api/user/steam/wishlist/preview")
async def preview_steam_wishlist(
    current_user: NamedDependency[User],
) -> list[steam_service.SteamPreviewItem]:
    operation_lock = _get_user_operation_lock(current_user.id)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)
    try:
        async with operation_lock, async_session() as db_session:
            return await steam_service.preview_wishlist(
                db_session, current_user, steamgriddb_api_key
            )
    except ValidationError as error:
        raise ClientException(str(error)) from error
    except httpx.HTTPError as error:
        raise ServiceUnavailableException(_STEAM_UNAVAILABLE) from error


@post(
    "/api/user/steam/wishlist/import/stream",
    status_code=200,
    media_type="text/event-stream",
)
async def import_steam_wishlist_stream(
    data: list[SteamWishlistItem],
    current_user: NamedDependency[User],
) -> ServerSentEvent:
    """SSE variant of a wishlist import - see sync_steam_playtimes_stream's
    docstring. Unlike the library import, the item list is POSTed by the
    client from the preview the user confirmed rather than re-fetched from
    Steam, so the import always matches what was previewed."""
    _validate_wishlist_items(data)
    items = data
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)
    operation_lock = _get_user_operation_lock(current_user.id)

    async def run(on_progress: steam_service.ProgressCallback) -> list[BacklogEntry]:
        async with operation_lock, async_session() as db_session:
            return await steam_service.import_wishlist(
                db_session,
                current_user,
                items,
                steamgriddb_api_key=steamgriddb_api_key,
                on_progress=on_progress,
            )

    return ServerSentEvent(_stream_steam_operation(run))


@post(
    "/api/user/steam/library/preview/stream",
    status_code=200,
    media_type="text/event-stream",
)
async def preview_steam_library_stream(
    current_user: NamedDependency[User],
) -> ServerSentEvent:
    """SSE variant of a library preview: emits a `progress` event per
    owned game considered, then a `done` event carrying the
    SteamPreviewItem list, or an `error` event - see
    sync_steam_playtimes_stream's docstring. Nothing is written to the
    DB; the actual import runs through import_steam_library_stream once
    the user has confirmed the preview."""
    api_key = _resolve_api_key(current_user)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)
    family_steam_ids = _resolve_family_steam_ids(current_user)
    operation_lock = _get_user_operation_lock(current_user.id)

    async def run(
        on_progress: steam_service.ProgressCallback,
    ) -> list[steam_service.SteamPreviewItem]:
        async with operation_lock, async_session() as db_session:
            return await steam_service.preview_library(
                db_session,
                current_user,
                api_key,
                steamgriddb_api_key=steamgriddb_api_key,
                on_progress=on_progress,
                family_steam_ids=family_steam_ids,
            )

    return ServerSentEvent(_stream_steam_messages(run, lambda items: msgspec.json.encode(items).decode()))


steam_router = Router(
    path="",
    route_handlers=[
        sync_steam_playtimes,
        import_steam_library,
        sync_steam_playtimes_stream,
        import_steam_library_stream,
        get_steam_achievements,
        preview_steam_wishlist,
        import_steam_wishlist_stream,
        preview_steam_library_stream,
    ],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
    cache_control=_NO_STORE,
)

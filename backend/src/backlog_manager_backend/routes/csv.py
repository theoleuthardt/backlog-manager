import asyncio
import contextlib
from collections.abc import AsyncIterator, Awaitable, Callable

import msgspec
from cryptography.fernet import InvalidToken
from litestar import Router, post
from litestar.datastructures import CacheControlHeader
from litestar.di import NamedDependency, Provide
from litestar.response import ServerSentEvent, ServerSentEventMessage

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.auth.encryption import decrypt
from backlog_manager_backend.config import settings
from backlog_manager_backend.csv.parse_csv import (
    ColumnConfig,
    extract_csv_headers,
    parse_csv_content,
)
from backlog_manager_backend.csv.preview import (
    CsvPreviewItem,
    ProgressCallback,
    SubmitCsvEntry,
    build_csv_preview,
    submit_csv_entries,
)
from backlog_manager_backend.db import async_session
from backlog_manager_backend.integrations.types import IGDBCredentials
from backlog_manager_backend.schemas.backlog_entry import BacklogEntryResponse
from backlog_manager_backend.schemas.csv import (
    CsvHeadersRequest,
    CsvHeadersResponse,
    MatchCsvRequest,
)
from backlog_manager_backend.schemas.user import User

_NO_STORE = CacheControlHeader(no_store=True)
_SSE_DONE = "done"
_SSE_ERROR = "error"
_SSE_PROGRESS = "progress"

_user_import_locks: dict[int, asyncio.Lock] = {}


def _resolve_igdb_credentials(user: User) -> tuple[str, str] | None:
    """Best-effort IGDB credential resolution for CSV import's genre/
    cover enrichment - unlike routes/games.py::_resolve_igdb_credentials
    (which this mirrors), missing/broken credentials resolve to None
    rather than raising: a CSV preview should still work with
    HowLongToBeat-only matching when IGDB isn't configured, not fail
    outright."""
    if user.igdb_credentials_encrypted and settings.steam_api_key_encryption_key:
        try:
            decrypted = decrypt(
                user.igdb_credentials_encrypted, settings.steam_api_key_encryption_key
            )
            credentials = msgspec.json.decode(decrypted, type=IGDBCredentials)
        except (InvalidToken, ValueError, msgspec.DecodeError):
            return None
        return credentials.client_id, credentials.client_secret
    if settings.igdb_client_id and settings.igdb_client_secret:
        return settings.igdb_client_id, settings.igdb_client_secret
    return None


def _resolve_steamgriddb_api_key(user: User) -> str | None:
    """Mirrors routes/games.py::_resolve_steamgriddb_api_key, also
    resolving to None (rather than raising) on a broken key so it
    degrades the same way a missing key already does."""
    if user.steamgriddb_api_key_encrypted and settings.steam_api_key_encryption_key:
        try:
            return decrypt(user.steamgriddb_api_key_encrypted, settings.steam_api_key_encryption_key)
        except (InvalidToken, ValueError):
            return None
    return settings.steamgriddb_api_key


def _get_user_import_lock(user_id: int) -> asyncio.Lock:
    """Mirrors routes/steam.py's per-user operation lock: a second CSV
    preview/submit for the same user while one is already running would
    otherwise race against it (e.g. two submits creating the same row
    twice) rather than being rejected or queued."""
    lock = _user_import_locks.get(user_id)
    if lock is None:
        lock = asyncio.Lock()
        _user_import_locks[user_id] = lock
    return lock


def _column_config(data: MatchCsvRequest) -> ColumnConfig:
    return ColumnConfig(
        title_column=data.title_column,
        genre_column=data.genre_column,
        platform_column=data.platform_column,
        status_column=data.status_column,
        playtime_column=data.playtime_column,
        rating_column=data.rating_column,
        completed_at_column=data.completed_at_column,
        note_columns=data.note_columns,
        review_columns=data.review_columns,
    )


async def _stream_csv_messages[T](
    run: Callable[[ProgressCallback], Awaitable[list[T]]],
    encode_result: Callable[[list[T]], str],
) -> AsyncIterator[ServerSentEventMessage]:
    """SSE bridge for the CSV preview/submit endpoints - mirrors
    routes/steam.py's `_stream_steam_messages` (kept as a separate copy
    rather than a shared import to avoid touching the Steam import
    flow's own SSE machinery)."""
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
            await queue.put(ServerSentEventMessage(event=_SSE_DONE, data=encode_result(result)))
        except Exception as error:  # noqa: BLE001 - reported as an SSE error event, not left to crash the stream
            await queue.put(ServerSentEventMessage(event=_SSE_ERROR, data=str(error)))
        finally:
            await queue.put(None)

    task = asyncio.create_task(run_operation())
    try:
        while (message := await queue.get()) is not None:
            yield message
    finally:
        if not task.done():
            task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


@post("/api/csv/headers", status_code=200)
async def get_csv_headers(
    data: CsvHeadersRequest, current_user: NamedDependency[User]
) -> CsvHeadersResponse:
    """Reads just the header row so the import UI can label each column
    picker with its real name instead of a blind spreadsheet letter."""
    return CsvHeadersResponse(headers=extract_csv_headers(data.content))


@post("/api/csv/preview/stream", status_code=200, media_type="text/event-stream")
async def preview_csv_stream(data: MatchCsvRequest, current_user: NamedDependency[User]) -> ServerSentEvent:
    """SSE preview: parses+matches every row against HowLongToBeat and
    the user's existing backlog without writing anything - mirrors
    routes/steam.py's preview_steam_library_stream. The user confirms
    (and can edit or drop) rows from this preview before submit_csv_stream
    actually creates them."""
    records = parse_csv_content(data.content)
    headers = extract_csv_headers(data.content)
    config = _column_config(data)
    igdb_credentials = _resolve_igdb_credentials(current_user)
    steamgriddb_api_key = _resolve_steamgriddb_api_key(current_user)
    lock = _get_user_import_lock(current_user.id)

    async def run(on_progress: ProgressCallback) -> list[CsvPreviewItem]:
        async with lock, async_session() as db_session:
            return await build_csv_preview(
                db_session,
                current_user.id,
                records,
                config,
                headers=headers,
                igdb_credentials=igdb_credentials,
                steamgriddb_api_key=steamgriddb_api_key,
                on_progress=on_progress,
            )

    return ServerSentEvent(
        _stream_csv_messages(run, lambda items: msgspec.json.encode(items).decode())
    )


@post("/api/csv/submit/stream", status_code=200, media_type="text/event-stream")
async def submit_csv_stream(
    data: list[SubmitCsvEntry], current_user: NamedDependency[User]
) -> ServerSentEvent:
    """SSE submit: creates the entries the user confirmed in the preview
    - mirrors routes/steam.py's import_steam_wishlist_stream, which also
    takes the client-confirmed item list as the POST body rather than
    recomputing anything server-side."""
    lock = _get_user_import_lock(current_user.id)

    async def run(on_progress: ProgressCallback) -> list[BacklogEntryResponse]:
        async with lock, async_session() as db_session:
            created = await submit_csv_entries(db_session, current_user.id, data, on_progress)
            return [BacklogEntryResponse.from_entry(entry) for entry in created]

    return ServerSentEvent(
        _stream_csv_messages(run, lambda items: msgspec.json.encode(items).decode())
    )


csv_router = Router(
    path="",
    route_handlers=[get_csv_headers, preview_csv_stream, submit_csv_stream],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
    cache_control=_NO_STORE,
)

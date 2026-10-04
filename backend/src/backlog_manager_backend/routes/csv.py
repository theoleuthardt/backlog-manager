import asyncio
from collections.abc import AsyncIterator, Awaitable, Callable

import msgspec
import structlog
from litestar import Router, post
from litestar.datastructures import CacheControlHeader
from litestar.di import NamedDependency, Provide
from litestar.response import ServerSentEvent, ServerSentEventMessage

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.csv.parse_csv import (
    ColumnConfig,
    extract_csv_headers,
    parse_csv_content,
)
from backlog_manager_backend.csv.preview import (
    CsvPreviewItem,
    ProgressCallback,
    SkippedCsvEntry,
    SubmitCsvEntry,
    build_csv_preview,
    submit_csv_entries,
)
from backlog_manager_backend.db import async_session
from backlog_manager_backend.routes import sse
from backlog_manager_backend.schemas.backlog_entry import BacklogEntryResponse
from backlog_manager_backend.schemas.csv import (
    CsvHeadersRequest,
    CsvHeadersResponse,
    MatchCsvRequest,
)
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import backup_service
from backlog_manager_backend.services.credentials import (
    resolve_igdb_credentials_or_none,
    resolve_steamgriddb_api_key_or_none,
)

logger = structlog.get_logger()

_NO_STORE = CacheControlHeader(no_store=True)
_EXTERNAL_SERVICE_UNAVAILABLE = "An external game database is currently unavailable"
_IMPORT_FAILED = "Import failed - check the server logs for details"

_user_import_locks: dict[int, asyncio.Lock] = {}


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


def _stream_csv_messages[R](
    run: Callable[[ProgressCallback], Awaitable[R]],
    encode_result: Callable[[R], str],
) -> AsyncIterator[ServerSentEventMessage]:
    return sse.stream_operation(
        run,
        encode_result,
        service_unavailable_message=_EXTERNAL_SERVICE_UNAVAILABLE,
        failure_message=_IMPORT_FAILED,
        log_event="csv_import_stream_failed",
    )


@post("/api/csv/headers", status_code=200)
async def get_csv_headers(
    data: CsvHeadersRequest, current_user: NamedDependency[User]
) -> CsvHeadersResponse:
    """Reads just the header row so the import UI can label each column
    picker with its real name instead of a blind spreadsheet letter."""
    return CsvHeadersResponse(headers=extract_csv_headers(data.content))


@post("/api/csv/preview/stream", status_code=200, media_type="text/event-stream")
async def preview_csv_stream(
    data: MatchCsvRequest, current_user: NamedDependency[User]
) -> ServerSentEvent:
    """SSE preview: parses+matches every row against HowLongToBeat and
    the user's existing backlog without writing anything - mirrors
    routes/steam.py's preview_steam_library_stream. The user confirms
    (and can edit or drop) rows from this preview before submit_csv_stream
    actually creates them."""
    records = parse_csv_content(data.content)
    headers = extract_csv_headers(data.content)
    config = _column_config(data)
    igdb_credentials = resolve_igdb_credentials_or_none(current_user)
    steamgriddb_api_key = resolve_steamgriddb_api_key_or_none(current_user)
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


class SubmitCsvStreamResult(msgspec.Struct):
    created: list[BacklogEntryResponse]
    skipped: list[SkippedCsvEntry]


@post("/api/csv/submit/stream", status_code=200, media_type="text/event-stream")
async def submit_csv_stream(
    data: list[SubmitCsvEntry], current_user: NamedDependency[User]
) -> ServerSentEvent:
    """SSE submit: creates the entries the user confirmed in the preview
    - mirrors routes/steam.py's import_steam_wishlist_stream, which also
    takes the client-confirmed item list as the POST body rather than
    recomputing anything server-side."""
    lock = _get_user_import_lock(current_user.id)

    async def run(on_progress: ProgressCallback) -> SubmitCsvStreamResult:
        async with lock, async_session() as db_session:
            await backup_service.create_backup(
                db_session, current_user.id, backup_service.PRE_IMPORT
            )
            result = await submit_csv_entries(db_session, current_user.id, data, on_progress)
            return SubmitCsvStreamResult(
                created=[BacklogEntryResponse.from_entry(entry) for entry in result.created],
                skipped=result.skipped,
            )

    return ServerSentEvent(
        _stream_csv_messages(run, lambda result: msgspec.json.encode(result).decode())
    )


csv_router = Router(
    path="",
    route_handlers=[get_csv_headers, preview_csv_stream, submit_csv_stream],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
    cache_control=_NO_STORE,
)

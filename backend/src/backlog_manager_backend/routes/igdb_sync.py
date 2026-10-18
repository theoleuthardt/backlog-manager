import asyncio

import msgspec
from litestar import Router, get, post
from litestar.datastructures import CacheControlHeader
from litestar.di import NamedDependency, Provide
from litestar.exceptions import NotFoundException, ServiceUnavailableException
from litestar.params import FromQuery
from litestar.response import ServerSentEvent
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.db import async_session
from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.routes import sse
from backlog_manager_backend.schemas.backlog_entry import BacklogEntry, BacklogEntryResponse
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import igdb_sync_service
from backlog_manager_backend.services.credentials import resolve_igdb_credentials_or_none

_IGDB_NOT_CONFIGURED = "IGDB integration is not configured"
_IGDB_UNAVAILABLE = "IGDB is currently unreachable"
_IGDB_SYNC_FAILED = "IGDB sync failed - check the server logs for details"
_SPACE_NOT_FOUND = "Space not found"
_NO_STORE = CacheControlHeader(no_store=True)

_user_operation_locks: dict[int, asyncio.Lock] = {}


def _get_user_operation_lock(user_id: int) -> asyncio.Lock:
    lock = _user_operation_locks.get(user_id)
    if lock is None:
        lock = asyncio.Lock()
        _user_operation_locks[user_id] = lock
    return lock


@get("/api/igdb-sync/pending-count", raises=[NotFoundException])
async def get_pending_count(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> int:
    """How many entries the IGDB sync would touch (personal ones, or those
    of the shared space with `space_id`, 404 for a non-member) - the number
    the confirmation dialog shows before the user starts it."""
    try:
        return await igdb_sync_service.count_entries_needing_sync(
            db_session, current_user.id, space_id
        )
    except NotFoundError as error:
        raise NotFoundException(_SPACE_NOT_FOUND) from error


@post(
    "/api/igdb-sync/stream",
    status_code=200,
    media_type="text/event-stream",
    raises=[NotFoundException],
)
async def sync_igdb_data_stream(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> ServerSentEvent:
    """SSE endpoint: a `progress` event after every candidate entry looked
    up, then a `done` event carrying the updated entries, or an `error`
    event - see sse.stream_operation."""
    if space_id is not None:
        try:
            await igdb_sync_service.count_entries_needing_sync(
                db_session, current_user.id, space_id
            )
        except NotFoundError as error:
            raise NotFoundException(_SPACE_NOT_FOUND) from error
    igdb_credentials = resolve_igdb_credentials_or_none(current_user)
    if igdb_credentials is None:
        raise ServiceUnavailableException(_IGDB_NOT_CONFIGURED)
    operation_lock = _get_user_operation_lock(current_user.id)

    async def run(on_progress: sse.ProgressCallback) -> list[BacklogEntry]:
        async with operation_lock, async_session() as sync_session:
            return await igdb_sync_service.sync_igdb_data(
                sync_session,
                current_user,
                igdb_credentials,
                on_progress=on_progress,
                space_id=space_id,
            )

    def encode_result(entries: list[BacklogEntry]) -> str:
        return msgspec.json.encode(
            [BacklogEntryResponse.from_entry(entry) for entry in entries]
        ).decode()

    return ServerSentEvent(
        sse.stream_operation(
            run,
            encode_result,
            service_unavailable_message=_IGDB_UNAVAILABLE,
            failure_message=_IGDB_SYNC_FAILED,
            log_event="igdb_sync_stream_failed",
        )
    )


igdb_sync_router = Router(
    path="",
    route_handlers=[get_pending_count, sync_igdb_data_stream],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
    cache_control=_NO_STORE,
)

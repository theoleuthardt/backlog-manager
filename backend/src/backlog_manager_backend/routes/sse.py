"""SSE bridge shared by the long-running Steam and CSV import endpoints.

Services report progress through a plain async callback and return their
final result, so they cannot be generators themselves; `stream_operation`
runs one in a background task and drains a queue of progress/done/error
messages into the response stream."""

import asyncio
import contextlib
from collections.abc import AsyncIterator, Awaitable, Callable

import httpx
import msgspec
import structlog
from litestar.response import ServerSentEventMessage

from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError

logger = structlog.get_logger()

SSE_DONE = "done"
SSE_ERROR = "error"
SSE_PROGRESS = "progress"

ProgressCallback = Callable[[int, int], Awaitable[None]]


async def stream_operation[R](
    run: Callable[[ProgressCallback], Awaitable[R]],
    encode_result: Callable[[R], str],
    *,
    service_unavailable_message: str,
    failure_message: str,
    log_event: str,
) -> AsyncIterator[ServerSentEventMessage]:
    """`run` must open and close its own db session (e.g. via
    `async with async_session() as db_session`) rather than taking one as a
    NamedDependency: Litestar closes a streaming handler's dependencies as
    soon as the handler returns the response object, which happens before
    this generator (and therefore `run`) ever executes.

    Any failure is reported as an SSE error event rather than left to crash
    the stream. Only known domain errors (raised with an already-safe,
    user-facing message) are forwarded as-is; an unreachable external
    service gets `service_unavailable_message`; anything else is logged
    under `log_event` and reported as `failure_message`, since its str()
    can carry raw SQL or driver detail that must not reach the client. If
    the client disconnects, the background task is cancelled."""
    queue: asyncio.Queue[ServerSentEventMessage | None] = asyncio.Queue()

    async def on_progress(processed: int, total: int) -> None:
        await queue.put(
            ServerSentEventMessage(
                event=SSE_PROGRESS,
                data=msgspec.json.encode({"processed": processed, "total": total}).decode(),
            )
        )

    async def run_operation() -> None:
        try:
            result = await run(on_progress)
            await queue.put(ServerSentEventMessage(event=SSE_DONE, data=encode_result(result)))
        except (ConflictError, NotFoundError, ValidationError) as error:
            await queue.put(ServerSentEventMessage(event=SSE_ERROR, data=str(error)))
        except httpx.HTTPError:
            await queue.put(
                ServerSentEventMessage(event=SSE_ERROR, data=service_unavailable_message)
            )
        except Exception as error:  # noqa: BLE001
            logger.error(log_event, error=str(error))
            await queue.put(ServerSentEventMessage(event=SSE_ERROR, data=failure_message))
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

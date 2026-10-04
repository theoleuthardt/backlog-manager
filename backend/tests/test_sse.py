import asyncio

import httpx
import pytest

from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError


@pytest.fixture
def sse(postgres_url: str):
    from backlog_manager_backend.routes import sse as module

    return module


async def _collect(sse, run, encode=lambda result: str(result)):
    return [
        (message.event, message.data)
        async for message in sse.stream_operation(
            run,
            encode,
            service_unavailable_message="service down",
            failure_message="operation failed",
            log_event="test_stream_failed",
        )
    ]


async def test_stream_reports_progress_then_done(sse) -> None:
    async def run(on_progress):
        await on_progress(1, 2)
        await on_progress(2, 2)
        return ["a", "b"]

    messages = await _collect(sse, run)

    assert messages == [
        ("progress", '{"processed":1,"total":2}'),
        ("progress", '{"processed":2,"total":2}'),
        ("done", "['a', 'b']"),
    ]


@pytest.mark.parametrize("error", [ValidationError("bad input"), ConflictError("already there")])
async def test_stream_forwards_domain_error_messages(sse, error: Exception) -> None:
    async def run(on_progress):
        raise error

    assert await _collect(sse, run) == [("error", str(error))]


async def test_stream_forwards_not_found_errors(sse) -> None:
    async def run(on_progress):
        raise NotFoundError("User", 7)

    messages = await _collect(sse, run)

    assert [event for event, _ in messages] == ["error"]


async def test_stream_reports_an_unreachable_service(sse) -> None:
    async def run(on_progress):
        raise httpx.ConnectError("boom")

    assert await _collect(sse, run) == [("error", "service down")]


async def test_stream_reports_unexpected_errors_generically_without_leaking_details(sse) -> None:
    async def run(on_progress):
        raise RuntimeError("SELECT secret FROM users failed")

    messages = await _collect(sse, run)

    assert messages == [("error", "operation failed")]


async def test_stream_cancels_the_operation_when_the_client_disconnects(sse) -> None:
    finished = asyncio.Event()
    cancelled = asyncio.Event()

    async def run(on_progress):
        await on_progress(1, 10)
        try:
            await asyncio.sleep(30)
        except asyncio.CancelledError:
            cancelled.set()
            raise
        finished.set()
        return []

    stream = sse.stream_operation(
        run,
        str,
        service_unavailable_message="service down",
        failure_message="operation failed",
        log_event="test_stream_failed",
    )
    first = await anext(stream)
    await stream.aclose()

    assert first.event == "progress"
    assert cancelled.is_set()
    assert not finished.is_set()

import json
from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.discord import send_discord_webhook_message


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


async def test_send_discord_webhook_message_posts_content(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    received: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        received["url"] = str(request.url)
        received["body"] = json.loads(request.content)
        return httpx.Response(204)

    _mock_client(handler, monkeypatch)

    await send_discord_webhook_message("https://discord.com/api/webhooks/1/abc", "Sale!")

    assert received["url"] == "https://discord.com/api/webhooks/1/abc"
    assert received["body"] == {"content": "Sale!"}


async def test_send_discord_webhook_message_swallows_http_errors(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    _mock_client(handler, monkeypatch)

    await send_discord_webhook_message("https://discord.com/api/webhooks/1/abc", "Sale!")


async def test_send_discord_webhook_message_swallows_transport_errors(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    await send_discord_webhook_message("https://discord.com/api/webhooks/1/abc", "Sale!")

import json
from collections.abc import Callable

import httpx
import pytest
import structlog.testing

from backlog_manager_backend.integrations.discord import (
    is_valid_discord_webhook_url,
    send_discord_webhook_message,
)

_WEBHOOK_URL = "https://discord.com/api/webhooks/123456789012345678/super-secret-token"


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


async def test_send_discord_webhook_message_posts_content_and_returns_true(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    received: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        received["url"] = str(request.url)
        received["body"] = json.loads(request.content)
        return httpx.Response(204)

    _mock_client(handler, monkeypatch)

    delivered = await send_discord_webhook_message(_WEBHOOK_URL, "Sale!")

    assert delivered is True
    assert received["url"] == _WEBHOOK_URL
    assert received["body"] == {"content": "Sale!"}


async def test_send_discord_webhook_message_returns_false_on_http_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    _mock_client(handler, monkeypatch)

    delivered = await send_discord_webhook_message(_WEBHOOK_URL, "Sale!")

    assert delivered is False


async def test_send_discord_webhook_message_returns_false_on_transport_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    delivered = await send_discord_webhook_message(_WEBHOOK_URL, "Sale!")

    assert delivered is False


async def test_send_discord_webhook_message_never_logs_the_webhook_url(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """httpx.HTTPStatusError's own message embeds the failing request's
    URL - since that URL is the webhook's bearer secret, the logged
    fields must never include it, only the status code."""

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404)

    _mock_client(handler, monkeypatch)

    with structlog.testing.capture_logs() as logs:
        delivered = await send_discord_webhook_message(_WEBHOOK_URL, "Sale!")

    assert delivered is False
    logged_text = json.dumps(logs)
    assert "super-secret-token" not in logged_text
    assert _WEBHOOK_URL not in logged_text


def test_is_valid_discord_webhook_url_accepts_real_webhook_urls() -> None:
    assert is_valid_discord_webhook_url(_WEBHOOK_URL) is True
    assert is_valid_discord_webhook_url(
        "https://discordapp.com/api/webhooks/123/token-with-dashes_and_underscores"
    ) is True
    assert is_valid_discord_webhook_url(
        "https://canary.discord.com/api/webhooks/123/token"
    ) is True


def test_is_valid_discord_webhook_url_rejects_non_discord_urls() -> None:
    assert is_valid_discord_webhook_url("http://internal.example/steal-alerts") is False
    assert is_valid_discord_webhook_url("https://discord.com/not-a-webhook") is False
    assert is_valid_discord_webhook_url("https://evil.com/discord.com/api/webhooks/1/x") is False
    assert is_valid_discord_webhook_url("ftp://discord.com/api/webhooks/1/x") is False

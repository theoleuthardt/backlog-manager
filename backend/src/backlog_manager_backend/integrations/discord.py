import re

import httpx
import structlog

logger = structlog.get_logger()

_WEBHOOK_URL_PATTERN = re.compile(
    r"^https://(?:ptb\.|canary\.)?discord(?:app)?\.com/api/webhooks/\d+/[\w-]+/?$"
)


def is_valid_discord_webhook_url(url: str) -> bool:
    """True only for a real Discord webhook URL. Checked both where a
    webhook is written (routes/user.py, before it's ever encrypted) and
    where one is resolved for sending (price_service), since an
    unvalidated value here would let the price-check sweep be pointed
    at an arbitrary internal or attacker-controlled address."""
    return bool(_WEBHOOK_URL_PATTERN.match(url))


async def send_discord_webhook_message(webhook_url: str, content: str) -> bool:
    """Best-effort delivery: returns True only if Discord accepted the
    message, so a caller can gate persisting alert-dedup state on
    actual delivery rather than just the attempt. A Discord outage or
    misconfigured webhook must not break the price-check sweep that
    calls this, so failures are logged and swallowed rather than
    raised - by status code/exception type only, never the raw error
    message, since httpx.HTTPStatusError embeds the request URL and
    this URL is itself the webhook's bearer secret."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(10.0)) as client:
            response = await client.post(webhook_url, json={"content": content})
        response.raise_for_status()
    except httpx.HTTPStatusError as error:
        logger.error("Discord webhook error", status_code=error.response.status_code)
        return False
    except httpx.HTTPError as error:
        logger.error("Discord webhook error", error_type=type(error).__name__)
        return False
    return True

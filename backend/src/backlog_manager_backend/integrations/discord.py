import httpx
import structlog

logger = structlog.get_logger()


async def send_discord_webhook_message(webhook_url: str, content: str) -> None:
    """Best-effort: a Discord outage or misconfigured webhook must not
    break the price-check sweep that calls this, so failures are logged
    and swallowed rather than raised."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(10.0)) as client:
            response = await client.post(webhook_url, json={"content": content})
        response.raise_for_status()
    except httpx.HTTPError as error:
        logger.error("Discord webhook error", error=str(error))

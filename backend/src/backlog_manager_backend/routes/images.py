from urllib.parse import urlparse

import httpx
import structlog
from litestar import Response, get
from litestar.params import FromQuery
from litestar.status_codes import HTTP_400_BAD_REQUEST, HTTP_404_NOT_FOUND

logger = structlog.get_logger()

# Only these hosts are ever proxied - this is a public, unauthenticated
# passthrough, so an open allowlist would let this endpoint be abused as a
# generic anonymizing image fetcher for arbitrary URLs.
_ALLOWED_HOSTS = {"howlongtobeat.com", "images.igdb.com"}

_TIMEOUT = httpx.Timeout(15.0)

_BASE_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
}


def _headers_for(host: str) -> dict[str, str]:
    """howlongtobeat.com rejects hotlinked image requests without a
    same-site Referer/Origin - images.igdb.com doesn't need this, but
    sending it wouldn't hurt either; kept host-specific to match exactly
    what the original frontend proxy did."""
    headers = dict(_BASE_HEADERS)
    if host == "howlongtobeat.com":
        headers["Referer"] = "https://howlongtobeat.com/"
        headers["Origin"] = "https://howlongtobeat.com"
    return headers


@get("/api/images/proxy")
async def proxy_image(url: FromQuery[str]) -> Response:
    host = urlparse(url).hostname
    if host not in _ALLOWED_HOSTS:
        return Response("Invalid URL", status_code=HTTP_400_BAD_REQUEST, media_type="text/plain")

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            upstream = await client.get(url, headers=_headers_for(host))
    except httpx.HTTPError as error:
        logger.error("Error proxying image", url=url, error=str(error))
        return Response(
            "Failed to fetch image", status_code=HTTP_404_NOT_FOUND, media_type="text/plain"
        )

    if upstream.status_code >= 400:
        logger.error("Upstream image error", url=url, status_code=upstream.status_code)
        return Response(
            "Image not found", status_code=HTTP_404_NOT_FOUND, media_type="text/plain"
        )

    return Response(
        upstream.content,
        media_type=upstream.headers.get("content-type", "image/jpeg"),
        headers={
            "Cache-Control": "public, max-age=86400, immutable",
            "Access-Control-Allow-Origin": "*",
        },
    )

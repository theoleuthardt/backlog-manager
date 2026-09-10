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
_ALLOWED_HOSTS = {
    "howlongtobeat.com",
    "images.igdb.com",
    "media.steampowered.com",
    "steamcdn-a.akamaihd.net",
    "www.cheapshark.com",
}

# steamstatic.com (Steam achievement icons) and steamgriddb.com (cover art)
# each use several interchangeable CDN subdomains, so the apex + subdomains
# are allowed rather than one fixed host per provider.
_ALLOWED_HOST_SUFFIXES = (".steamstatic.com", ".steamgriddb.com")
_ALLOWED_APEX_HOSTS = {"steamstatic.com", "steamgriddb.com"}


def _is_allowed_host(hostname: str | None) -> bool:
    if hostname is None:
        return False
    if hostname in _ALLOWED_HOSTS or hostname in _ALLOWED_APEX_HOSTS:
        return True
    return hostname.endswith(_ALLOWED_HOST_SUFFIXES)


# Only inert raster formats are ever returned - forwarding an upstream's
# Content-Type verbatim (e.g. text/html from a misconfigured host, or
# image/svg+xml, which can embed <script>) would let this endpoint serve
# attacker-influenced content the browser might render as more than a
# picture.
_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif", "image/avif"}

# A generous ceiling for a game cover image - bounds memory use per request
# regardless of what an allowlisted host (or a compromised/misconfigured
# one) claims or actually sends, since an unauthenticated caller could
# otherwise request a very large resource repeatedly to exhaust memory.
_MAX_IMAGE_BYTES = 10 * 1024 * 1024

_TIMEOUT = httpx.Timeout(15.0)

_BASE_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
}

_INVALID_URL = Response("Invalid URL", status_code=HTTP_400_BAD_REQUEST, media_type="text/plain")
_NOT_FOUND = Response("Image not found", status_code=HTTP_404_NOT_FOUND, media_type="text/plain")
_TOO_LARGE = Response("Image too large", status_code=HTTP_400_BAD_REQUEST, media_type="text/plain")
_UNSUPPORTED_TYPE = Response(
    "Unsupported content type", status_code=HTTP_400_BAD_REQUEST, media_type="text/plain"
)


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


# media.steampowered.com redirects to the actual asset rather than serving
# it directly; each hop below is re-validated against the same allowlist.
_MAX_REDIRECTS = 5


async def _fetch_following_allowed_redirects(
    client: httpx.AsyncClient, url: str
) -> httpx.Response | None:
    current_url = url
    for _ in range(_MAX_REDIRECTS + 1):
        request = client.build_request(
            "GET", current_url, headers=_headers_for(urlparse(current_url).hostname)
        )
        response = await client.send(request, stream=True, follow_redirects=False)
        if not response.is_redirect:
            return response

        await response.aclose()
        location = response.headers.get("location")
        if not location:
            return None
        next_url = str(httpx.URL(current_url).join(location))
        next_parsed = urlparse(next_url)
        if next_parsed.scheme != "https" or not _is_allowed_host(next_parsed.hostname):
            logger.error("Rejected redirect to a non-allowlisted host", url=next_url)
            return None
        current_url = next_url

    logger.error("Too many redirects proxying image", url=url)
    return None


@get("/api/images/proxy")
async def proxy_image(url: FromQuery[str]) -> Response:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not _is_allowed_host(parsed.hostname):
        return _INVALID_URL

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            upstream = await _fetch_following_allowed_redirects(client, url)
            if upstream is None:
                return _NOT_FOUND

            try:
                if upstream.status_code >= 400:
                    logger.error(
                        "Upstream image error", url=url, status_code=upstream.status_code
                    )
                    return _NOT_FOUND

                content_type = upstream.headers.get("content-type", "").split(";")[0].strip().lower()
                if content_type not in _ALLOWED_CONTENT_TYPES:
                    logger.error(
                        "Rejected unsupported image content type",
                        url=url,
                        content_type=content_type,
                    )
                    return _UNSUPPORTED_TYPE

                content_length = upstream.headers.get("content-length")
                if content_length is not None and int(content_length) > _MAX_IMAGE_BYTES:
                    return _TOO_LARGE

                body = bytearray()
                async for chunk in upstream.aiter_bytes():
                    body.extend(chunk)
                    if len(body) > _MAX_IMAGE_BYTES:
                        return _TOO_LARGE
            finally:
                await upstream.aclose()
    except httpx.HTTPError as error:
        logger.error("Error proxying image", url=url, error=str(error))
        return _NOT_FOUND

    return Response(
        bytes(body),
        media_type=content_type,
        headers={
            "Cache-Control": "public, max-age=86400, immutable",
            "Access-Control-Allow-Origin": "*",
        },
    )

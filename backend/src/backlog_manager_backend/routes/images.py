import hashlib
from collections import OrderedDict
from typing import NamedTuple
from urllib.parse import urlparse

import httpx
import structlog
from litestar import Request, Response, get
from litestar.params import FromQuery
from litestar.status_codes import (
    HTTP_304_NOT_MODIFIED,
    HTTP_400_BAD_REQUEST,
    HTTP_404_NOT_FOUND,
)

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

# steamstatic.com (Steam achievement icons), steamgriddb.com (cover art) and
# thegamesdb.net (cover art) each use several interchangeable CDN subdomains,
# so the apex + subdomains are allowed rather than one fixed host per provider.
_ALLOWED_HOST_SUFFIXES = (
    ".steamstatic.com",
    ".steamgriddb.com",
    ".thegamesdb.net",
)
_ALLOWED_APEX_HOSTS = {"steamstatic.com", "steamgriddb.com", "thegamesdb.net"}


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

_CACHE_MAX_BYTES = 1024 * 1024 * 1024

_CACHE_HEADERS = {
    "Cache-Control": "public, max-age=86400, immutable",
    "Access-Control-Allow-Origin": "*",
}


class _CachedImage(NamedTuple):
    body: bytes
    content_type: str
    etag: str


class _ImageCache:
    """Byte-bounded in-memory LRU of proxied covers, keyed by upstream URL.

    Large backlogs request hundreds of covers per dashboard load; serving
    repeats from memory spares the upstream hosts (which rate-limit) and
    cuts latency. Only successfully validated images are ever stored.
    """

    def __init__(self, max_bytes: int) -> None:
        self._max_bytes = max_bytes
        self._size = 0
        self._entries: OrderedDict[str, _CachedImage] = OrderedDict()

    def get(self, url: str) -> _CachedImage | None:
        entry = self._entries.get(url)
        if entry is not None:
            self._entries.move_to_end(url)
        return entry

    def put(self, url: str, body: bytes, content_type: str) -> _CachedImage:
        entry = _CachedImage(body, content_type, f'"{hashlib.sha256(body).hexdigest()[:32]}"')
        if len(body) > self._max_bytes:
            return entry
        previous = self._entries.pop(url, None)
        if previous is not None:
            self._size -= len(previous.body)
        self._entries[url] = entry
        self._size += len(body)
        while self._size > self._max_bytes:
            _, evicted = self._entries.popitem(last=False)
            self._size -= len(evicted.body)
        return entry

    def clear(self) -> None:
        self._entries.clear()
        self._size = 0


_image_cache = _ImageCache(_CACHE_MAX_BYTES)


def clear_image_cache() -> None:
    """Empties the proxy cache (used by tests for isolation)."""
    _image_cache.clear()


def _respond(image: _CachedImage, request: Request) -> Response:
    headers = {**_CACHE_HEADERS, "ETag": image.etag}
    if request.headers.get("if-none-match") == image.etag:
        return Response(b"", status_code=HTTP_304_NOT_MODIFIED, headers=headers)
    return Response(image.body, media_type=image.content_type, headers=headers)

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
async def proxy_image(url: FromQuery[str], request: Request) -> Response:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not _is_allowed_host(parsed.hostname):
        return _INVALID_URL

    cached = _image_cache.get(url)
    if cached is not None:
        return _respond(cached, request)

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            upstream = await _fetch_following_allowed_redirects(client, url)
            if upstream is None:
                return _NOT_FOUND

            try:
                if upstream.status_code >= 400:
                    logger.error("Upstream image error", url=url, status_code=upstream.status_code)
                    return _NOT_FOUND

                content_type = (
                    upstream.headers.get("content-type", "").split(";")[0].strip().lower()
                )
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

    return _respond(_image_cache.put(url, bytes(body), content_type), request)

from collections.abc import Callable

import httpx
import pytest
from litestar.testing import TestClient

_URL = "https://images.igdb.com/igdb/image/upload/t_cover_big/cache-me.png"


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


async def test_proxy_image_serves_repeat_requests_from_cache(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import images

    images.clear_image_cache()
    upstream_calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal upstream_calls
        upstream_calls += 1
        return httpx.Response(200, content=b"cached-bytes", headers={"content-type": "image/png"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        first = client.get("/api/images/proxy", params={"url": _URL})
        second = client.get("/api/images/proxy", params={"url": _URL})

    assert first.content == second.content == b"cached-bytes"
    assert second.headers["content-type"] == "image/png"
    assert upstream_calls == 1


async def test_proxy_image_returns_304_for_matching_etag(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import images

    images.clear_image_cache()

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"etag-bytes", headers={"content-type": "image/png"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        first = client.get("/api/images/proxy", params={"url": _URL})
        conditional = client.get(
            "/api/images/proxy",
            params={"url": _URL},
            headers={"If-None-Match": first.headers["etag"]},
        )

    assert conditional.status_code == 304
    assert conditional.content == b""


def test_image_cache_evicts_least_recently_used_over_budget() -> None:
    from backlog_manager_backend.routes.images import _ImageCache

    cache = _ImageCache(max_bytes=10)
    cache.put("a", b"1234", "image/png")
    cache.put("b", b"1234", "image/png")
    assert cache.get("a") is not None
    cache.put("c", b"1234", "image/png")

    assert cache.get("b") is None
    assert cache.get("a") is not None
    assert cache.get("c") is not None

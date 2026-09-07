from collections.abc import Callable

import httpx
import pytest
from litestar.testing import TestClient


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


async def test_proxy_image_streams_igdb_image(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://images.igdb.com/igdb/image/upload/t_cover_big/abc.jpg"
        return httpx.Response(200, content=b"fake-image-bytes", headers={"content-type": "image/jpeg"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://images.igdb.com/igdb/image/upload/t_cover_big/abc.jpg"},
        )

    assert response.status_code == 200
    assert response.content == b"fake-image-bytes"
    assert response.headers["content-type"] == "image/jpeg"
    assert response.headers["cache-control"] == "public, max-age=86400, immutable"


async def test_proxy_image_sends_referer_and_origin_for_hltb(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Referer"] == "https://howlongtobeat.com/"
        assert request.headers["Origin"] == "https://howlongtobeat.com"
        return httpx.Response(200, content=b"cover", headers={"content-type": "image/png"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://howlongtobeat.com/games/some-cover.jpg"},
        )

    assert response.status_code == 200
    assert response.content == b"cover"


async def test_proxy_image_rejects_non_allowlisted_host(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("should never call out for a disallowed host")

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy", params={"url": "https://evil.example.com/steal-my-data"}
        )

    assert response.status_code == 400


async def test_proxy_image_returns_404_on_upstream_error(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404)

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://images.igdb.com/igdb/image/upload/t_cover_big/missing.jpg"},
        )

    assert response.status_code == 404


async def test_proxy_image_returns_404_on_transport_failure(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://images.igdb.com/igdb/image/upload/t_cover_big/abc.jpg"},
        )

    assert response.status_code == 404


async def test_proxy_image_rejects_non_https_url(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("should never call out for a non-https URL")

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "http://images.igdb.com/igdb/image/upload/t_cover_big/abc.jpg"},
        )

    assert response.status_code == 400


async def test_proxy_image_rejects_unsupported_content_type(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200, content=b"<script>alert(1)</script>", headers={"content-type": "image/svg+xml"}
        )

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://images.igdb.com/igdb/image/upload/t_cover_big/abc.svg"},
        )

    assert response.status_code == 400


async def test_proxy_image_rejects_oversized_response(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import images as images_module

    monkeypatch.setattr(images_module, "_MAX_IMAGE_BYTES", 10)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            content=b"way more than ten bytes of image data" * 10,
            headers={"content-type": "image/jpeg"},
        )

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://images.igdb.com/igdb/image/upload/t_cover_big/huge.jpg"},
        )

    assert response.status_code == 400

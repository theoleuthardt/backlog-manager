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


async def test_proxy_image_streams_steam_achievement_icon(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    icon_url = (
        "https://cdn.akamai.steamstatic.com/steamcommunity/public/images/apps/620/"
        "e3a2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2.jpg"
    )

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == icon_url
        return httpx.Response(200, content=b"achievement-icon", headers={"content-type": "image/jpeg"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/images/proxy", params={"url": icon_url})

    assert response.status_code == 200
    assert response.content == b"achievement-icon"


async def test_proxy_image_streams_steam_achievement_icon_from_akamaihd(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    """GetSchemaForGame's icon URLs are actually served from
    steamcdn-a.akamaihd.net in practice, not steamstatic.com or
    media.steampowered.com - confirmed against the real Steam Web API.
    Only this exact host is allowed, not the whole akamaihd.net domain,
    which fronts unrelated third-party content too."""
    from backlog_manager_backend.app import create_app

    icon_url = (
        "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/208650/"
        "f4c6527e2d55eca5d1f2bdb6d5d8efd1a901262e.jpg"
    )

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == icon_url
        return httpx.Response(200, content=b"achievement-icon", headers={"content-type": "image/jpeg"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/images/proxy", params={"url": icon_url})

    assert response.status_code == 200
    assert response.content == b"achievement-icon"


async def test_proxy_image_streams_cheapshark_store_icon(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    icon_url = "https://www.cheapshark.com/img/stores/icons/0.png"

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == icon_url
        return httpx.Response(200, content=b"store-icon", headers={"content-type": "image/png"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/images/proxy", params={"url": icon_url})

    assert response.status_code == 200
    assert response.content == b"store-icon"


async def test_proxy_image_rejects_other_akamaihd_hosts(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("should never call out for an unrelated akamaihd.net host")

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://some-other-customer.akamaihd.net/steal-my-data.jpg"},
        )

    assert response.status_code == 400


@pytest.mark.parametrize(
    "icon_url",
    [
        "https://cdn.akamai.steamstatic.com/steamcommunity/public/images/apps/620/hash.jpg",
        "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/620/hash.jpg",
        "https://shared.fastly.steamstatic.com/community_assets/images/apps/620/hash.jpg",
        "https://steamstatic.com/some/path/hash.jpg",
    ],
)
async def test_proxy_image_allows_steamstatic_subdomains(
    icon_url: str, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"icon", headers={"content-type": "image/jpeg"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/images/proxy", params={"url": icon_url})

    assert response.status_code == 200


@pytest.mark.parametrize(
    "cover_url",
    [
        "https://cdn2.steamgriddb.com/grid/hash.png",
        "https://steamgriddb.com/some/path/hash.png",
    ],
)
async def test_proxy_image_allows_steamgriddb_subdomains(
    cover_url: str, monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"cover", headers={"content-type": "image/png"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/images/proxy", params={"url": cover_url})

    assert response.status_code == 200


async def test_proxy_image_rejects_steamgriddb_lookalike_host(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("should never call out for a lookalike host")

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://evilsteamgriddb.com/steal-my-data.png"},
        )

    assert response.status_code == 400


async def test_proxy_image_follows_redirect_from_media_steampowered_to_steamstatic(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    icon_url = (
        "https://media.steampowered.com/steamcommunity/public/images/apps/620/hash.jpg"
    )
    cdn_url = "https://cdn.akamai.steamstatic.com/steamcommunity/public/images/apps/620/hash.jpg"

    def handler(request: httpx.Request) -> httpx.Response:
        if str(request.url) == icon_url:
            return httpx.Response(302, headers={"location": cdn_url})
        if str(request.url) == cdn_url:
            return httpx.Response(200, content=b"icon", headers={"content-type": "image/jpeg"})
        raise AssertionError(f"unexpected request: {request.url}")

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/images/proxy", params={"url": icon_url})

    assert response.status_code == 200
    assert response.content == b"icon"


async def test_proxy_image_rejects_redirect_to_a_non_allowlisted_host(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    icon_url = "https://media.steampowered.com/redirect-me.jpg"

    def handler(request: httpx.Request) -> httpx.Response:
        if str(request.url) == icon_url:
            return httpx.Response(
                302, headers={"location": "https://evil.example.com/steal.jpg"}
            )
        raise AssertionError("should never follow a redirect to a non-allowlisted host")

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get("/api/images/proxy", params={"url": icon_url})

    assert response.status_code == 404


async def test_proxy_image_rejects_too_many_redirects(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            302, headers={"location": "https://media.steampowered.com/next.jpg"}
        )

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://media.steampowered.com/start.jpg"},
        )

    assert response.status_code == 404


async def test_proxy_image_follows_exactly_max_redirects_before_the_final_response(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    """_MAX_REDIRECTS redirects followed by a real response must still
    succeed - only exceeding that count should be rejected."""
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import images as images_module

    hop_count = images_module._MAX_REDIRECTS

    def handler(request: httpx.Request) -> httpx.Response:
        hop = int(request.url.path.removeprefix("/hop-").removesuffix(".jpg"))
        if hop < hop_count:
            return httpx.Response(
                302, headers={"location": f"https://media.steampowered.com/hop-{hop + 1}.jpg"}
            )
        return httpx.Response(200, content=b"icon", headers={"content-type": "image/jpeg"})

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://media.steampowered.com/hop-0.jpg"},
        )

    assert response.status_code == 200
    assert response.content == b"icon"


async def test_proxy_image_rejects_steamstatic_lookalike_host(
    monkeypatch: pytest.MonkeyPatch, postgres_url: str
) -> None:
    from backlog_manager_backend.app import create_app

    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("should never call out for a lookalike host")

    _mock_client(handler, monkeypatch)

    with TestClient(app=create_app()) as client:
        response = client.get(
            "/api/images/proxy",
            params={"url": "https://evilsteamstatic.com/steal-my-data.jpg"},
        )

    assert response.status_code == 400


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

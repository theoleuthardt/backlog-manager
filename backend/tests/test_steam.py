from collections.abc import Callable

import httpx
import pytest

from backlog_manager_backend.integrations.steam import (
    get_achievement_schema,
    get_owned_games,
    get_player_achievements,
    get_wishlist,
)

_SAMPLE_RESPONSE = {
    "response": {
        "game_count": 2,
        "games": [
            {"appid": 504230, "name": "Celeste", "playtime_forever": 510},
            {"appid": 220, "name": "Half-Life 2", "playtime_forever": 0},
        ],
    }
}


def _mock_client(
    handler: Callable[[httpx.Request], httpx.Response], monkeypatch: pytest.MonkeyPatch
) -> None:
    transport = httpx.MockTransport(handler)

    class _MockAsyncClient(httpx.AsyncClient):
        def __init__(self, *args: object, **kwargs: object) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockAsyncClient)


async def test_get_owned_games_returns_parsed_results(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["key"] == "api-key"
        assert request.url.params["steamid"] == "1234"
        assert request.url.params["include_played_free_games"] == "1"
        return httpx.Response(200, json=_SAMPLE_RESPONSE)

    _mock_client(handler, monkeypatch)

    games = await get_owned_games("1234", "api-key")

    assert len(games) == 2
    assert games[0].appid == 504230
    assert games[0].name == "Celeste"
    assert games[0].playtime_forever == 510


async def test_get_owned_games_returns_empty_list_when_games_omitted(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"response": {}})

    _mock_client(handler, monkeypatch)

    assert await get_owned_games("1234", "api-key") == []


async def test_get_owned_games_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_owned_games("1234", "bad-key")


async def test_get_owned_games_raises_on_malformed_json(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not json")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_owned_games("1234", "api-key")


async def test_get_owned_games_raises_on_schema_mismatch(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"response": {"games": [{"appid": "not-an-int"}]}})

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_owned_games("1234", "api-key")


async def test_get_owned_games_raises_on_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_owned_games("1234", "api-key")


_SAMPLE_PLAYER_ACHIEVEMENTS_RESPONSE = {
    "playerstats": {
        "steamID": "1234",
        "gameName": "Celeste",
        "achievements": [
            {
                "apiname": "ach_a",
                "achieved": 1,
                "unlocktime": 1000,
                "name": "Achievement A",
                "description": "Do the thing",
            },
            {"apiname": "ach_b", "achieved": 0, "unlocktime": 0, "name": "Achievement B"},
        ],
        "success": True,
    }
}


async def test_get_player_achievements_returns_parsed_results(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["key"] == "api-key"
        assert request.url.params["steamid"] == "1234"
        assert request.url.params["appid"] == "504230"
        return httpx.Response(200, json=_SAMPLE_PLAYER_ACHIEVEMENTS_RESPONSE)

    _mock_client(handler, monkeypatch)

    stats = await get_player_achievements("1234", 504230, "api-key")

    assert stats.success is True
    assert len(stats.achievements) == 2
    assert stats.achievements[0].apiname == "ach_a"
    assert stats.achievements[0].achieved == 1


async def test_get_player_achievements_returns_unsuccessful_when_app_has_no_stats(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200, json={"playerstats": {"success": False, "error": "Requested app has no stats"}}
        )

    _mock_client(handler, monkeypatch)

    stats = await get_player_achievements("1234", 504230, "api-key")

    assert stats.success is False
    assert stats.achievements == []


async def test_get_player_achievements_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_player_achievements("1234", 504230, "bad-key")


async def test_get_player_achievements_raises_on_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_player_achievements("1234", 504230, "api-key")


_SAMPLE_SCHEMA_RESPONSE = {
    "game": {
        "gameName": "Celeste",
        "gameVersion": "1",
        "availableGameStats": {
            "achievements": [
                {
                    "name": "ach_a",
                    "defaultvalue": 0,
                    "displayName": "Achievement A",
                    "hidden": 0,
                    "description": "Do the thing",
                    "icon": "https://example.com/a.jpg",
                    "icongray": "https://example.com/a_gray.jpg",
                }
            ]
        },
    }
}


async def test_get_achievement_schema_returns_parsed_results(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["key"] == "api-key"
        assert request.url.params["appid"] == "504230"
        return httpx.Response(200, json=_SAMPLE_SCHEMA_RESPONSE)

    _mock_client(handler, monkeypatch)

    schema = await get_achievement_schema(504230, "api-key")

    assert len(schema) == 1
    assert schema[0].name == "ach_a"
    assert schema[0].display_name == "Achievement A"
    assert schema[0].icon == "https://example.com/a.jpg"


async def test_get_achievement_schema_returns_empty_list_when_game_has_no_stats(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"game": {"gameName": "Celeste", "gameVersion": "1"}})

    _mock_client(handler, monkeypatch)

    assert await get_achievement_schema(504230, "api-key") == []


async def test_get_achievement_schema_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_achievement_schema(504230, "bad-key")


async def test_get_achievement_schema_raises_on_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_achievement_schema(504230, "api-key")


_SAMPLE_WISHLIST_RESPONSE = {
    "response": {
        "items": [
            {"appid": 620, "priority": 0, "date_added": 1600000000},
            {"appid": 504230, "priority": 2, "date_added": 1600000100},
        ]
    }
}


async def test_get_wishlist_returns_parsed_results(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["steamid"] == "1234"
        return httpx.Response(200, json=_SAMPLE_WISHLIST_RESPONSE)

    _mock_client(handler, monkeypatch)

    items = await get_wishlist("1234")

    assert len(items) == 2
    assert items[0].appid == 620
    assert items[0].priority == 0
    assert items[0].date_added == 1600000000


async def test_get_wishlist_returns_empty_list_for_private_profile(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"response": {}})

    _mock_client(handler, monkeypatch)

    assert await get_wishlist("1234") == []


async def test_get_wishlist_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_wishlist("1234")


async def test_get_wishlist_raises_on_malformed_json(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not json")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_wishlist("1234")


async def test_get_wishlist_raises_on_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_wishlist("1234")


async def test_get_app_details_returns_data(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.integrations.steam import get_app_details

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["appids"] == "620"
        return httpx.Response(
            200,
            json={
                "620": {
                    "success": True,
                    "data": {
                        "name": "Portal 2",
                        "header_image": "https://example.com/portal2.jpg",
                    },
                }
            },
        )

    _mock_client(handler, monkeypatch)
    detail = await get_app_details(620)
    assert detail is not None
    assert detail.name == "Portal 2"
    assert detail.header_image == "https://example.com/portal2.jpg"


async def test_get_app_details_returns_none_when_unknown(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.integrations.steam import get_app_details

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["appids"] == "999999"
        return httpx.Response(200, json={"999999": {"success": False}})

    _mock_client(handler, monkeypatch)
    assert await get_app_details(999999) is None

async def test_get_steam_library_cover_if_exists_returns_url_when_200(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "HEAD"
        return httpx.Response(200)

    _mock_client(handler, monkeypatch)
    url = await get_steam_library_cover_if_exists(620)
    assert url == "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg"


async def test_get_steam_library_cover_if_exists_returns_none_when_404(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "HEAD"
        return httpx.Response(404)

    _mock_client(handler, monkeypatch)
    assert await get_steam_library_cover_if_exists(999999) is None


async def test_search_store_by_title_returns_parsed_results(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import search_store_by_title

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["term"] == "Celeste"
        return httpx.Response(
            200,
            json={
                "total": 2,
                "items": [
                    {"type": "app", "name": "Celeste", "id": 504230},
                    {"type": "dlc", "name": "Celeste Soundtrack", "id": 1092840},
                ],
            },
        )

    _mock_client(handler, monkeypatch)
    items = await search_store_by_title("Celeste")

    assert [(item.type, item.id) for item in items] == [("app", 504230), ("dlc", 1092840)]


async def test_search_store_by_title_returns_empty_list_when_no_match(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import search_store_by_title

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"total": 0, "items": []})

    _mock_client(handler, monkeypatch)
    assert await search_store_by_title("Some Unreleased Game") == []


async def test_search_store_by_title_raises_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.integrations.steam import search_store_by_title

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await search_store_by_title("Celeste")


async def test_search_store_by_title_raises_on_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    from backlog_manager_backend.integrations.steam import search_store_by_title

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await search_store_by_title("Celeste")

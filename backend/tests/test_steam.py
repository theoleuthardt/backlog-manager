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
    assert (
        url
        == "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg"
    )


async def test_get_steam_library_cover_if_exists_returns_none_when_404(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "HEAD":
            return httpx.Response(404)
        return httpx.Response(
            200, json={"response": {"store_items": [{"id": 999999, "success": 15}]}}
        )

    _mock_client(handler, monkeypatch)
    assert await get_steam_library_cover_if_exists(999999) is None


_HASHED_ASSETS_RESPONSE = {
    "response": {
        "store_items": [
            {
                "id": 4005900,
                "success": 1,
                "assets": {
                    "asset_url_format": "steam/apps/4005900/${FILENAME}?t=1761423838",
                    "library_capsule": "fb818ab4f28788436ee35b0b57fc1dbc9284fe45/library_capsule.jpg",
                    "library_capsule_2x": "fb818ab4f28788436ee35b0b57fc1dbc9284fe45/library_capsule_2x.jpg",
                },
            }
        ]
    }
}
_HASHED_COVER_URL = (
    "https://shared.steamstatic.com/store_item_assets/steam/apps/4005900/"
    "fb818ab4f28788436ee35b0b57fc1dbc9284fe45/library_capsule_2x.jpg?t=1761423838"
)


async def test_get_steam_library_cover_if_exists_falls_back_to_hashed_asset_path(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "HEAD":
            return httpx.Response(404)
        assert "IStoreBrowseService/GetItems" in request.url.path
        assert '"appid":4005900' in request.url.params["input_json"].replace(" ", "")
        return httpx.Response(200, json=_HASHED_ASSETS_RESPONSE)

    _mock_client(handler, monkeypatch)
    assert await get_steam_library_cover_if_exists(4005900) == _HASHED_COVER_URL


async def test_get_steam_library_cover_if_exists_prefers_direct_path_over_store_lookup(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "HEAD"
        return httpx.Response(200)

    _mock_client(handler, monkeypatch)
    assert await get_steam_library_cover_if_exists(620) is not None


async def test_get_steam_library_cover_if_exists_uses_1x_capsule_when_2x_missing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    payload = {
        "response": {
            "store_items": [
                {
                    "id": 1,
                    "success": 1,
                    "assets": {
                        "asset_url_format": "steam/apps/1/${FILENAME}?t=5",
                        "library_capsule": "abc/library_capsule.jpg",
                    },
                }
            ]
        }
    }

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "HEAD":
            return httpx.Response(404)
        return httpx.Response(200, json=payload)

    _mock_client(handler, monkeypatch)
    assert (
        await get_steam_library_cover_if_exists(1)
        == "https://shared.steamstatic.com/store_item_assets/steam/apps/1/abc/library_capsule.jpg?t=5"
    )


@pytest.mark.parametrize(
    "payload",
    [
        {"response": {}},
        {"response": {"store_items": [{"id": 9, "success": 15}]}},
        {
            "response": {
                "store_items": [
                    {"id": 9, "success": 1, "assets": {"asset_url_format": "x/${FILENAME}"}}
                ]
            }
        },
    ],
)
async def test_get_steam_library_cover_if_exists_returns_none_without_library_assets(
    monkeypatch: pytest.MonkeyPatch, payload: dict[str, object]
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "HEAD":
            return httpx.Response(404)
        return httpx.Response(200, json=payload)

    _mock_client(handler, monkeypatch)
    assert await get_steam_library_cover_if_exists(9) is None


async def test_get_steam_library_cover_if_exists_returns_none_when_store_lookup_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_steam_library_cover_if_exists

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "HEAD":
            return httpx.Response(404)
        return httpx.Response(500)

    _mock_client(handler, monkeypatch)
    assert await get_steam_library_cover_if_exists(9) is None


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


async def test_search_store_by_title_raises_on_missing_item_id(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import search_store_by_title

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"total": 1, "items": [{"type": "app", "name": "X"}]})

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await search_store_by_title("Celeste")


async def test_search_store_by_title_raises_on_missing_items(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import search_store_by_title

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"total": 1})

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await search_store_by_title("Celeste")


def _store_items_response(*items: dict[str, object]) -> dict[str, object]:
    return {"response": {"store_items": list(items)}}


async def test_get_store_items_returns_names_and_header_images_in_one_request(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import json

    from backlog_manager_backend.integrations.steam import get_store_items

    requests: list[dict[str, object]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.url.params["input_json"])
        requests.append(payload)
        return httpx.Response(
            200,
            json=_store_items_response(
                {
                    "id": 620,
                    "success": 1,
                    "name": "Portal 2",
                    "assets": {
                        "asset_url_format": "steam/apps/620/${FILENAME}?t=1",
                        "header": "header.jpg",
                    },
                },
                {"id": 504230, "success": 1, "name": "Celeste"},
            ),
        )

    _mock_client(handler, monkeypatch)

    details = await get_store_items([620, 504230])

    assert len(requests) == 1
    assert requests[0]["ids"] == [{"appid": 620}, {"appid": 504230}]
    assert details[620].name == "Portal 2"
    assert details[620].header_image == (
        "https://shared.steamstatic.com/store_item_assets/steam/apps/620/header.jpg?t=1"
    )
    assert details[504230].name == "Celeste"
    assert details[504230].header_image is None


async def test_get_store_items_skips_apps_without_a_name(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_store_items

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json=_store_items_response(
                {"id": 620, "success": 1, "name": "Portal 2"},
                {"id": 999999, "success": 15},
                {"id": 123, "success": 1, "name": ""},
            ),
        )

    _mock_client(handler, monkeypatch)

    assert set(await get_store_items([620, 999999, 123])) == {620}


async def test_get_store_items_splits_a_long_list_into_batches(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import json

    from backlog_manager_backend.integrations.steam import (
        STORE_ITEMS_BATCH_SIZE,
        get_store_items,
    )

    sizes: list[int] = []

    def handler(request: httpx.Request) -> httpx.Response:
        ids = json.loads(request.url.params["input_json"])["ids"]
        sizes.append(len(ids))
        return httpx.Response(
            200,
            json=_store_items_response(
                *(
                    {"id": item["appid"], "success": 1, "name": f"Game {item['appid']}"}
                    for item in ids
                )
            ),
        )

    _mock_client(handler, monkeypatch)

    app_ids = list(range(1, STORE_ITEMS_BATCH_SIZE * 2 + 6))
    details = await get_store_items(app_ids)

    assert sizes == [STORE_ITEMS_BATCH_SIZE, STORE_ITEMS_BATCH_SIZE, 5]
    assert len(details) == len(app_ids)


async def test_get_store_items_returns_nothing_for_an_empty_list(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_store_items

    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("no request expected")

    _mock_client(handler, monkeypatch)

    assert await get_store_items([]) == {}


async def test_get_store_items_raises_on_http_error(monkeypatch: pytest.MonkeyPatch) -> None:
    import asyncio

    from backlog_manager_backend.integrations.steam import get_store_items

    async def fake_sleep(seconds: float) -> None:
        return None

    monkeypatch.setattr(asyncio, "sleep", fake_sleep)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPError):
        await get_store_items([620])


async def test_get_app_details_retries_when_the_store_rate_limits(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import asyncio

    from backlog_manager_backend.integrations.steam import get_app_details

    sleeps: list[float] = []

    async def fake_sleep(seconds: float) -> None:
        sleeps.append(seconds)

    monkeypatch.setattr(asyncio, "sleep", fake_sleep)
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls < 3:
            return httpx.Response(429)
        return httpx.Response(
            200, json={"620": {"success": True, "data": {"name": "Portal 2", "header_image": None}}}
        )

    _mock_client(handler, monkeypatch)

    detail = await get_app_details(620)

    assert detail is not None
    assert detail.name == "Portal 2"
    assert calls == 3
    assert sleeps == sorted(sleeps)
    assert all(seconds > 0 for seconds in sleeps)


async def test_get_app_details_gives_up_after_the_last_retry(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import asyncio

    from backlog_manager_backend.integrations.steam import get_app_details

    async def fake_sleep(seconds: float) -> None:
        return None

    monkeypatch.setattr(asyncio, "sleep", fake_sleep)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(429)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_app_details(620)


async def test_get_app_details_does_not_retry_a_client_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from backlog_manager_backend.integrations.steam import get_app_details

    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        return httpx.Response(404)

    _mock_client(handler, monkeypatch)

    with pytest.raises(httpx.HTTPStatusError):
        await get_app_details(620)
    assert calls == 1


async def test_get_store_items_pauses_between_batches(monkeypatch: pytest.MonkeyPatch) -> None:
    import asyncio

    from backlog_manager_backend.integrations.steam import (
        STORE_ITEMS_BATCH_PAUSE_SECONDS,
        STORE_ITEMS_BATCH_SIZE,
        get_store_items,
    )

    pauses: list[float] = []

    async def fake_sleep(seconds: float) -> None:
        pauses.append(seconds)

    monkeypatch.setattr(asyncio, "sleep", fake_sleep)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=_store_items_response())

    _mock_client(handler, monkeypatch)

    await get_store_items(list(range(1, STORE_ITEMS_BATCH_SIZE * 3 + 1)))

    assert pauses == [STORE_ITEMS_BATCH_PAUSE_SECONDS] * 2

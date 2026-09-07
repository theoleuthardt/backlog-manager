import asyncio
from types import ModuleType

import httpx
import pytest

from backlog_manager_backend.integrations.types import (
    EnrichedResult,
    HltbResultData,
    IGDBCover,
    IGDBGameData,
    IGDBGameTimeToBeat,
    IGDBGenre,
    IGDBPlatform,
    IGDBSearchResult,
    IGDBTokenResponse,
    SteamApp,
    SteamGridDBGrid,
)


@pytest.fixture
def game_service(monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    """Imported lazily (rather than at module scope) so this file can be
    collected before the postgres_url fixture has set POSTGRES_URL - the
    module chain game_service -> config eagerly builds Settings() on
    import, which requires that env var to already be set."""
    from backlog_manager_backend.services import game_service as module

    monkeypatch.setattr(module, "_cached_token", None)
    monkeypatch.setattr(module, "_genre_cache", {})
    monkeypatch.setattr(module, "_platform_cache", {})
    monkeypatch.setattr(module, "_game_cache", {})
    monkeypatch.setattr(module, "_cover_cache", {})
    monkeypatch.setattr(module, "_time_to_beat_cache", {})
    monkeypatch.setattr(module, "_steam_app_id_by_title", {})
    monkeypatch.setattr(module, "_steam_app_list_cached_at", None)
    monkeypatch.setattr(module, "_steam_app_list_last_attempt_at", None)
    monkeypatch.setattr(module, "_steamgriddb_cover_cache", {})
    monkeypatch.setattr(module.settings, "igdb_client_id", "cid")
    monkeypatch.setattr(module.settings, "igdb_client_secret", "secret")
    monkeypatch.setattr(module.settings, "steamgriddb_api_key", None)
    return module


async def test_get_valid_token_raises_without_credentials(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "igdb_client_id", None)

    with pytest.raises(RuntimeError, match="IGDB credentials not configured"):
        await game_service.get_valid_token()


async def test_get_valid_token_fetches_and_caches(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    call_count = 0

    async def fake_generate_token(client_id: str, client_secret: str) -> IGDBTokenResponse:
        nonlocal call_count
        call_count += 1
        return IGDBTokenResponse(access_token="tok", expires_in=3600, token_type="bearer")

    monkeypatch.setattr(game_service, "generate_igdb_token", fake_generate_token)

    first = await game_service.get_valid_token()
    second = await game_service.get_valid_token()

    assert first == "tok"
    assert second == "tok"
    assert call_count == 1


async def test_search_reuses_cached_genre_and_platform_names(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    genres_call_count = 0
    platforms_call_count = 0

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Celeste", cover=None, genres=[10], platforms=[6])]

    async def fake_get_genres_on_igdb(
        genre_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGenre]:
        nonlocal genres_call_count
        genres_call_count += 1
        return [IGDBGenre(id=10, name="Platformer")]

    async def fake_get_platforms_on_igdb(
        platform_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBPlatform]:
        nonlocal platforms_call_count
        platforms_call_count += 1
        return [IGDBPlatform(id=6, name="PC")]

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return [IGDBGameTimeToBeat(id=1, game_id=1, normally=3600)]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(game_service, "get_genres_on_igdb", fake_get_genres_on_igdb)
    monkeypatch.setattr(game_service, "get_platforms_on_igdb", fake_get_platforms_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    await game_service.search("Celeste")
    await game_service.search("Celeste")

    assert genres_call_count == 1
    assert platforms_call_count == 1


async def test_search_falls_back_to_hltb_when_igdb_has_no_beat_time(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Celeste", cover=5, genres=[10], platforms=[6])]

    async def fake_get_covers_on_igdb(
        cover_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBCover]:
        return [IGDBCover(id=5, image_id="abc123")]

    async def fake_get_genres_on_igdb(
        genre_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGenre]:
        return [IGDBGenre(id=10, name="Platformer")]

    async def fake_get_platforms_on_igdb(
        platform_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBPlatform]:
        return [IGDBPlatform(id=6, name="PC")]

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return []

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        return [
            HltbResultData(
                id=999,
                hltb_id=999,
                title="Celeste",
                image_url="https://example.com/celeste.jpg",
                main_story=8.5,
                main_story_with_extras=12.0,
                completionist=37.0,
                last_updated_at="2024-01-01",
            )
        ]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(game_service, "get_covers_on_igdb", fake_get_covers_on_igdb)
    monkeypatch.setattr(game_service, "get_genres_on_igdb", fake_get_genres_on_igdb)
    monkeypatch.setattr(game_service, "get_platforms_on_igdb", fake_get_platforms_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "search_game_on_hltb", fake_search_game_on_hltb)
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("Celeste")

    assert results == [
        EnrichedResult(
            id=1,
            hltb_id=999,
            title="Celeste",
            image_url="https://images.igdb.com/igdb/image/upload/t_cover_big/abc123.jpg",
            genres=["Platformer"],
            platforms=["PC"],
            main_story=8.5,
            main_story_with_extras=12.0,
            completionist=37.0,
        )
    ]


async def test_search_batches_multiple_results_into_one_call_each(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Direct regression test for issue #105's N+1 slowdown: enriching
    multiple search results must hit each IGDB endpoint exactly once,
    not once per result."""
    call_counts: dict[str, int] = {
        "games": 0,
        "covers": 0,
        "genres": 0,
        "platforms": 0,
        "time_to_beat": 0,
    }

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [
            IGDBSearchResult(id=1, game=1, name="Celeste"),
            IGDBSearchResult(id=2, game=2, name="Hollow Knight"),
        ]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        call_counts["games"] += 1
        return [
            IGDBGameData(id=1, name="Celeste", cover=5, genres=[10], platforms=[6]),
            IGDBGameData(id=2, name="Hollow Knight", cover=8, genres=[10], platforms=[6]),
        ]

    async def fake_get_covers_on_igdb(
        cover_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBCover]:
        call_counts["covers"] += 1
        return [IGDBCover(id=5, image_id="abc"), IGDBCover(id=8, image_id="def")]

    async def fake_get_genres_on_igdb(
        genre_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGenre]:
        call_counts["genres"] += 1
        return [IGDBGenre(id=10, name="Platformer")]

    async def fake_get_platforms_on_igdb(
        platform_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBPlatform]:
        call_counts["platforms"] += 1
        return [IGDBPlatform(id=6, name="PC")]

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        call_counts["time_to_beat"] += 1
        return [
            IGDBGameTimeToBeat(id=1, game_id=1, normally=3600),
            IGDBGameTimeToBeat(id=2, game_id=2, normally=7200),
        ]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(game_service, "get_covers_on_igdb", fake_get_covers_on_igdb)
    monkeypatch.setattr(game_service, "get_genres_on_igdb", fake_get_genres_on_igdb)
    monkeypatch.setattr(game_service, "get_platforms_on_igdb", fake_get_platforms_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("metroidvania")

    assert len(results) == 2
    assert call_counts == {"games": 1, "covers": 1, "genres": 1, "platforms": 1, "time_to_beat": 1}


async def test_search_reuses_cached_game_and_cover_data(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    games_call_count = 0
    covers_call_count = 0

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        nonlocal games_call_count
        games_call_count += 1
        return [IGDBGameData(id=1, name="Celeste", cover=5, genres=[], platforms=[])]

    async def fake_get_covers_on_igdb(
        cover_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBCover]:
        nonlocal covers_call_count
        covers_call_count += 1
        return [IGDBCover(id=5, image_id="abc")]

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return [IGDBGameTimeToBeat(id=1, game_id=1, normally=3600)]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(game_service, "get_covers_on_igdb", fake_get_covers_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    await game_service.search("Celeste")
    await game_service.search("Celeste")

    assert games_call_count == 1
    assert covers_call_count == 1


async def test_search_caches_hltb_fallback_time_to_beat(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    hltb_call_count = 0

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Celeste", cover=None, genres=[], platforms=[])]

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return []

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        nonlocal hltb_call_count
        hltb_call_count += 1
        return [
            HltbResultData(
                id=999,
                hltb_id=999,
                title="Celeste",
                image_url="https://example.com/celeste.jpg",
                main_story=8.5,
                main_story_with_extras=12.0,
                completionist=37.0,
                last_updated_at="2024-01-01",
            )
        ]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "search_game_on_hltb", fake_search_game_on_hltb)
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    await game_service.search("Celeste")
    await game_service.search("Celeste")

    assert hltb_call_count == 1


async def test_search_falls_back_to_hltb_when_igdb_time_to_beat_is_all_zero(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """An IGDB time-to-beat record with all durations zero/None must not
    be cached as "resolved" - that would permanently skip the HLTB
    fallback for a game IGDB has no real duration data for."""

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Celeste", cover=None, genres=[], platforms=[])]

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return [IGDBGameTimeToBeat(id=1, game_id=1, hastily=None, normally=None, completely=None)]

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        return [
            HltbResultData(
                id=999,
                hltb_id=999,
                title="Celeste",
                image_url="https://example.com/celeste.jpg",
                main_story=8.5,
                main_story_with_extras=12.0,
                completionist=37.0,
                last_updated_at="2024-01-01",
            )
        ]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "search_game_on_hltb", fake_search_game_on_hltb)
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("Celeste")

    assert results[0].hltb_id == 999
    assert results[0].main_story == 8.5


async def test_search_ranks_main_game_over_dlc_hits_that_crowd_it_out(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Regression test for issue #154: IGDB's /search endpoint matches
    DLC, bundles and alternate versions alongside the base game, and
    previously the raw search hits were truncated to
    _SEARCH_RESULT_LIMIT *before* being resolved to real games - so a
    title with more than _SEARCH_RESULT_LIMIT DLC/version hits could
    push the actual base game out of the raw slice entirely, and it
    would never appear in the results at all."""
    raw_hit_count = 10

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [
            IGDBSearchResult(id=game_id, game=game_id, name="SnowRunner - Season Pass")
            for game_id in range(1, raw_hit_count)
        ] + [IGDBSearchResult(id=raw_hit_count, game=raw_hit_count, name="SnowRunner")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        games = [
            IGDBGameData(
                id=game_id,
                name="SnowRunner - Season Pass",
                category=1,
                genres=[],
                platforms=[],
            )
            for game_id in range(1, raw_hit_count)
        ]
        games.append(
            IGDBGameData(
                id=raw_hit_count, name="SnowRunner", category=0, genres=[], platforms=[]
            )
        )
        return games

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return [
            IGDBGameTimeToBeat(id=game_id, game_id=game_id, normally=3600)
            for game_id in game_ids
        ]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("SnowRunner")

    assert len(results) == game_service._SEARCH_RESULT_LIMIT
    assert results[0].id == raw_hit_count
    assert results[0].title == "SnowRunner"


async def test_search_dedupes_multiple_raw_hits_resolving_to_the_same_game(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Regression test for issue #154: an alternate name and a
    character match can both resolve (via IGDBSearchResult.game) to the
    same underlying game id - that must not produce duplicate entries
    in the result list."""

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [
            IGDBSearchResult(id=101, game=1, name="Dave the Diver (alt name)"),
            IGDBSearchResult(id=102, game=1, name="Dave"),
            IGDBSearchResult(id=1, game=None, name="Dave the Diver"),
        ]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Dave the Diver", category=0, genres=[], platforms=[])]

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return [IGDBGameTimeToBeat(id=1, game_id=1, normally=3600)]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("Dave the Diver")

    assert len(results) == 1
    assert results[0].id == 1
    assert results[0].title == "Dave the Diver"


async def test_search_returns_empty_list_when_games_batch_fails(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A single flaky batched games call now affects the whole search
    (a deliberate trade-off vs. the old per-item isolation) - it must
    degrade gracefully to an empty list, not raise."""

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return []

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    assert await game_service.search("Celeste") == []


async def test_search_raises_without_client_id(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "igdb_client_id", None)

    with pytest.raises(RuntimeError, match="IGDB_CLIENT_ID not configured"):
        await game_service.search("Celeste")


async def test_find_steam_app_id_matches_by_exact_title(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def fake_get_steam_app_list() -> list[SteamApp]:
        return [
            SteamApp(appid=504230, name="Celeste"),
            SteamApp(appid=367520, name="Hollow Knight"),
        ]

    monkeypatch.setattr(game_service, "get_steam_app_list", fake_get_steam_app_list)

    assert await game_service.find_steam_app_id("Celeste") == 504230


async def test_find_steam_app_id_is_case_and_trademark_symbol_insensitive(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def fake_get_steam_app_list() -> list[SteamApp]:
        return [SteamApp(appid=8930, name="Sid Meier's Civilization® VI")]

    monkeypatch.setattr(game_service, "get_steam_app_list", fake_get_steam_app_list)

    assert (
        await game_service.find_steam_app_id("sid meier's civilization vi") == 8930
    )


async def test_find_steam_app_id_returns_none_when_no_match(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def fake_get_steam_app_list() -> list[SteamApp]:
        return [SteamApp(appid=504230, name="Celeste")]

    monkeypatch.setattr(game_service, "get_steam_app_list", fake_get_steam_app_list)

    assert await game_service.find_steam_app_id("Some Unreleased Game") is None


async def test_find_steam_app_id_caches_the_app_list_across_lookups(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    call_count = 0

    async def fake_get_steam_app_list() -> list[SteamApp]:
        nonlocal call_count
        call_count += 1
        return [SteamApp(appid=504230, name="Celeste")]

    monkeypatch.setattr(game_service, "get_steam_app_list", fake_get_steam_app_list)

    await game_service.find_steam_app_id("Celeste")
    await game_service.find_steam_app_id("Hollow Knight")

    assert call_count == 1


async def test_find_steam_app_id_returns_none_when_fetch_fails(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def fake_get_steam_app_list() -> list[SteamApp]:
        raise httpx.ConnectError("connection refused")

    monkeypatch.setattr(game_service, "get_steam_app_list", fake_get_steam_app_list)

    assert await game_service.find_steam_app_id("Celeste") is None


async def test_find_steam_app_id_backs_off_after_a_failed_fetch(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    call_count = 0

    async def failing_get_steam_app_list() -> list[SteamApp]:
        nonlocal call_count
        call_count += 1
        raise httpx.ConnectError("connection refused")

    monkeypatch.setattr(game_service, "get_steam_app_list", failing_get_steam_app_list)

    assert await game_service.find_steam_app_id("Celeste") is None
    assert await game_service.find_steam_app_id("Celeste") is None

    assert call_count == 1


async def test_find_steam_app_id_coalesces_concurrent_refreshes(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    call_count = 0
    started = asyncio.Event()
    proceed = asyncio.Event()

    async def slow_get_steam_app_list() -> list[SteamApp]:
        nonlocal call_count
        call_count += 1
        started.set()
        await proceed.wait()
        return [SteamApp(appid=504230, name="Celeste")]

    monkeypatch.setattr(game_service, "get_steam_app_list", slow_get_steam_app_list)

    async def lookup_after_fetch_started() -> int | None:
        await started.wait()
        return await game_service.find_steam_app_id("Celeste")

    first_task = asyncio.create_task(game_service.find_steam_app_id("Celeste"))
    second_task = asyncio.create_task(lookup_after_fetch_started())
    await started.wait()
    proceed.set()

    first_result, second_result = await asyncio.gather(first_task, second_task)

    assert call_count == 1
    assert first_result == 504230
    assert second_result == 504230


async def test_get_game_covers_raises_without_api_key(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "steamgriddb_api_key", None)

    with pytest.raises(RuntimeError, match="SteamGridDB API key not configured"):
        await game_service.get_game_covers(220)


async def test_get_game_covers_returns_urls_sorted_by_score(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "steamgriddb_api_key", "key")

    async def fake_get_grids_by_steam_app_id(
        steam_app_id: int, api_key: str
    ) -> list[SteamGridDBGrid]:
        return [
            SteamGridDBGrid(id=1, url="https://example.com/low.png", thumb="", score=10),
            SteamGridDBGrid(id=2, url="https://example.com/high.png", thumb="", score=90),
        ]

    monkeypatch.setattr(
        game_service, "get_grids_by_steam_app_id", fake_get_grids_by_steam_app_id
    )

    covers = await game_service.get_game_covers(220)

    assert covers == ["https://example.com/high.png", "https://example.com/low.png"]


async def test_get_game_covers_caches_across_calls(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "steamgriddb_api_key", "key")
    call_count = 0

    async def fake_get_grids_by_steam_app_id(
        steam_app_id: int, api_key: str
    ) -> list[SteamGridDBGrid]:
        nonlocal call_count
        call_count += 1
        return [SteamGridDBGrid(id=1, url="https://example.com/cover.png", thumb="")]

    monkeypatch.setattr(
        game_service, "get_grids_by_steam_app_id", fake_get_grids_by_steam_app_id
    )

    await game_service.get_game_covers(220)
    await game_service.get_game_covers(220)

    assert call_count == 1


async def test_get_game_covers_evicts_oldest_entry_once_cache_is_full(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "steamgriddb_api_key", "key")
    monkeypatch.setattr(game_service, "_STEAMGRIDDB_COVER_CACHE_MAX_SIZE", 2)

    async def fake_get_grids_by_steam_app_id(
        steam_app_id: int, api_key: str
    ) -> list[SteamGridDBGrid]:
        return [SteamGridDBGrid(id=steam_app_id, url=f"https://example.com/{steam_app_id}.png", thumb="")]

    monkeypatch.setattr(
        game_service, "get_grids_by_steam_app_id", fake_get_grids_by_steam_app_id
    )

    await game_service.get_game_covers(1)
    await game_service.get_game_covers(2)
    await game_service.get_game_covers(3)

    assert 1 not in game_service._steamgriddb_cover_cache
    assert 2 in game_service._steamgriddb_cover_cache
    assert 3 in game_service._steamgriddb_cover_cache


async def test_search_prefers_steamgriddb_cover_over_igdb(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "steamgriddb_api_key", "key")

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Celeste", cover=5, genres=[], platforms=[])]

    async def fake_get_covers_on_igdb(
        cover_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBCover]:
        return [IGDBCover(id=5, image_id="abc123")]

    async def fake_get_genres_on_igdb(
        genre_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGenre]:
        return []

    async def fake_get_platforms_on_igdb(
        platform_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBPlatform]:
        return []

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return [IGDBGameTimeToBeat(id=1, game_id=1, normally=3600)]

    async def fake_get_steam_app_list() -> list[SteamApp]:
        return [SteamApp(appid=504230, name="Celeste")]

    async def fake_get_grids_by_steam_app_id(
        steam_app_id: int, api_key: str
    ) -> list[SteamGridDBGrid]:
        return [SteamGridDBGrid(id=1, url="https://example.com/steamgriddb.png", thumb="")]

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(game_service, "get_covers_on_igdb", fake_get_covers_on_igdb)
    monkeypatch.setattr(game_service, "get_genres_on_igdb", fake_get_genres_on_igdb)
    monkeypatch.setattr(game_service, "get_platforms_on_igdb", fake_get_platforms_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "get_steam_app_list", fake_get_steam_app_list)
    monkeypatch.setattr(
        game_service, "get_grids_by_steam_app_id", fake_get_grids_by_steam_app_id
    )
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("Celeste")

    assert results[0].image_url == "https://example.com/steamgriddb.png"


async def test_search_falls_back_to_igdb_cover_when_steamgriddb_has_none(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "steamgriddb_api_key", "key")

    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_games_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Celeste", cover=5, genres=[], platforms=[])]

    async def fake_get_covers_on_igdb(
        cover_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBCover]:
        return [IGDBCover(id=5, image_id="abc123")]

    async def fake_get_genres_on_igdb(
        genre_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGenre]:
        return []

    async def fake_get_platforms_on_igdb(
        platform_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBPlatform]:
        return []

    async def fake_get_games_time_to_beat_on_igdb(
        game_ids: list[int], client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return [IGDBGameTimeToBeat(id=1, game_id=1, normally=3600)]

    async def fake_get_steam_app_list() -> list[SteamApp]:
        return [SteamApp(appid=504230, name="Celeste")]

    async def fake_get_grids_by_steam_app_id(
        steam_app_id: int, api_key: str
    ) -> list[SteamGridDBGrid]:
        return []

    async def fake_get_valid_token() -> str:
        return "tok"

    monkeypatch.setattr(game_service, "search_game_on_igdb", fake_search_game_on_igdb)
    monkeypatch.setattr(game_service, "get_games_on_igdb", fake_get_games_on_igdb)
    monkeypatch.setattr(game_service, "get_covers_on_igdb", fake_get_covers_on_igdb)
    monkeypatch.setattr(game_service, "get_genres_on_igdb", fake_get_genres_on_igdb)
    monkeypatch.setattr(game_service, "get_platforms_on_igdb", fake_get_platforms_on_igdb)
    monkeypatch.setattr(
        game_service, "get_games_time_to_beat_on_igdb", fake_get_games_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "get_steam_app_list", fake_get_steam_app_list)
    monkeypatch.setattr(
        game_service, "get_grids_by_steam_app_id", fake_get_grids_by_steam_app_id
    )
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("Celeste")

    assert results[0].image_url == (
        "https://images.igdb.com/igdb/image/upload/t_cover_big/abc123.jpg"
    )

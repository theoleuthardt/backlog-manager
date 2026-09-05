from types import ModuleType

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
    monkeypatch.setattr(module.settings, "igdb_client_id", "cid")
    monkeypatch.setattr(module.settings, "igdb_client_secret", "secret")
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


async def test_get_cached_genre_only_fetches_once(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    call_count = 0

    async def fake_get_genre(genre_id: int, client_id: str, access_token: str) -> list[IGDBGenre]:
        nonlocal call_count
        call_count += 1
        return [IGDBGenre(id=genre_id, name="Adventure")]

    monkeypatch.setattr(game_service, "get_genre_on_igdb", fake_get_genre)

    first = await game_service.get_cached_genre(10, "cid", "tok")
    second = await game_service.get_cached_genre(10, "cid", "tok")

    assert first == "Adventure"
    assert second == "Adventure"
    assert call_count == 1


async def test_process_in_batches_preserves_order_and_batches(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    sleep_calls = 0

    async def instant_sleep(_seconds: float) -> None:
        nonlocal sleep_calls
        sleep_calls += 1

    monkeypatch.setattr(game_service.asyncio, "sleep", instant_sleep)

    async def double(item: int) -> int:
        return item * 2

    results = await game_service.process_in_batches([1, 2, 3, 4, 5], batch_size=2, processor=double)

    assert results == [2, 4, 6, 8, 10]
    assert sleep_calls == 2


async def test_search_falls_back_to_hltb_when_igdb_has_no_beat_time(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def fake_search_game_on_igdb(
        search_term: str, client_id: str, access_token: str
    ) -> list[IGDBSearchResult]:
        return [IGDBSearchResult(id=1, game=1, name="Celeste")]

    async def fake_get_game_on_igdb(
        game_id: str, client_id: str, access_token: str
    ) -> list[IGDBGameData]:
        return [IGDBGameData(id=1, name="Celeste", cover=5, genres=[10], platforms=[6])]

    async def fake_get_cover_on_igdb(
        cover_id: int, client_id: str, access_token: str
    ) -> list[IGDBCover]:
        return [IGDBCover(id=5, image_id="abc123")]

    async def fake_get_genre_on_igdb(
        genre_id: int, client_id: str, access_token: str
    ) -> list[IGDBGenre]:
        return [IGDBGenre(id=10, name="Platformer")]

    async def fake_get_platform_on_igdb(
        platform_id: int, client_id: str, access_token: str
    ) -> list[IGDBPlatform]:
        return [IGDBPlatform(id=6, name="PC")]

    async def fake_get_game_time_to_beat_on_igdb(
        game_id: int, client_id: str, access_token: str
    ) -> list[IGDBGameTimeToBeat]:
        return []

    async def fake_search_game_on_hltb(search_term: str) -> list[HltbResultData]:
        return [
            HltbResultData(
                id=1,
                hltb_id=1,
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
    monkeypatch.setattr(game_service, "get_game_on_igdb", fake_get_game_on_igdb)
    monkeypatch.setattr(game_service, "get_cover_on_igdb", fake_get_cover_on_igdb)
    monkeypatch.setattr(game_service, "get_genre_on_igdb", fake_get_genre_on_igdb)
    monkeypatch.setattr(game_service, "get_platform_on_igdb", fake_get_platform_on_igdb)
    monkeypatch.setattr(
        game_service, "get_game_time_to_beat_on_igdb", fake_get_game_time_to_beat_on_igdb
    )
    monkeypatch.setattr(game_service, "search_game_on_hltb", fake_search_game_on_hltb)
    monkeypatch.setattr(game_service, "get_valid_token", fake_get_valid_token)

    results = await game_service.search("Celeste")

    assert results == [
        EnrichedResult(
            id=1,
            hltb_id=1,
            title="Celeste",
            image_url="https://images.igdb.com/igdb/image/upload/t_cover_big/abc123.jpg",
            genres=["Platformer"],
            platforms=["PC"],
            main_story=8.5,
            main_story_with_extras=12.0,
            completionist=37.0,
        )
    ]


async def test_search_raises_without_client_id(
    game_service: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(game_service.settings, "igdb_client_id", None)

    with pytest.raises(RuntimeError, match="IGDB_CLIENT_ID not configured"):
        await game_service.search("Celeste")

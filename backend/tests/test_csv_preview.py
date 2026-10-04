import asyncio
from datetime import UTC, datetime
from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.csv import preview
from backlog_manager_backend.csv.parse_csv import ColumnConfig
from backlog_manager_backend.errors import ConflictError, DatabaseError
from backlog_manager_backend.integrations.types import EnrichedResult, HltbResultData
from backlog_manager_backend.repositories import backlog_entry_repo, user_repo
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams
from backlog_manager_backend.schemas.user import CreateUserParams

_COMPLETED_AT = datetime(2026, 7, 1, tzinfo=UTC).replace(tzinfo=None)

_CONFIG = ColumnConfig(
    title_column="A",
    genre_column="B",
    platform_column="C",
    status_column="D",
    playtime_column="E",
    rating_column="F",
    completed_at_column="G",
    note_columns=["H"],
    review_columns=["I"],
)


async def _make_user(session: AsyncSession, username: str = "csvpreview") -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username=username, email=f"{username}@example.com", password_hash="h"),
    )


def _hltb_result(title: str) -> HltbResultData:
    return HltbResultData(
        id=1,
        hltb_id=1,
        title=title,
        image_url="https://example.com/cover.jpg",
        main_story=8.5,
        main_story_with_extras=12.0,
        completionist=37.0,
        last_updated_at="2024-01-01",
    )


def _igdb_result(
    title: str,
    genres: list[str] | None = None,
    description: str | None = None,
    trailer_url: str | None = None,
) -> EnrichedResult:
    return EnrichedResult(
        id=1,
        hltb_id=1,
        title=title,
        image_url="https://example.com/igdb-cover.jpg",
        genres=genres or ["Roguelike"],
        platforms=["PC"],
        main_story=10.0,
        main_story_with_extras=15.0,
        completionist=40.0,
        description=description,
        trailer_url=trailer_url,
    )


def _stub_igdb_token(monkeypatch: pytest.MonkeyPatch) -> None:
    """build_csv_preview validates IGDB credentials once, up front, by
    resolving a token before matching any row - stub it out wherever a
    test's credentials aren't meant to be exercised for real, mirroring
    how these tests already stub out game_service.search."""

    async def fake_get_valid_token(client_id: str, client_secret: str) -> str:
        return "fake-token"

    monkeypatch.setattr(preview.game_service, "get_valid_token", fake_get_valid_token)


async def test_build_csv_preview_maps_all_fields(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [
            {
                "A": "Celeste",
                "B": "Platformer",
                "C": "Owned",
                "D": "Finished",
                "E": "12.5",
                "F": "11",
                "G": "7.2026",
                "H": "Yes",
                "I": "Great game, loved the ending",
            }
        ],
        _CONFIG,
        headers={"H": "Stunner?"},
    )

    assert len(items) == 1
    item = items[0]
    assert item.title == "Celeste"
    assert item.genre == "Platformer"
    assert item.platform == ["PC"]
    assert item.status == "Completed"
    assert item.owned is True
    assert item.playtime == Decimal("12.5")
    assert item.review_stars == 10
    assert item.completed_at == _COMPLETED_AT
    assert item.note == "Stunner?: Yes"
    assert item.review == "Great game, loved the ending"
    assert item.matched is True
    assert item.image_link == "https://example.com/cover.jpg"
    assert item.duplicates == []


async def test_build_csv_preview_marks_unmatched_games(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_search(title: str) -> list[HltbResultData]:
        return []

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Unknown Game", "B": "RPG", "C": "Owned", "D": ""}],
        _CONFIG,
    )

    assert items[0].matched is False
    assert items[0].image_link is None
    assert items[0].status == "Not Started"


async def test_build_csv_preview_skips_rows_without_a_title(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    monkeypatch.setattr(preview, "search_game_on_hltb", lambda title: pytest.fail("unreachable"))

    items = await preview.build_csv_preview(
        session, user.id, [{"A": "", "B": "RPG", "C": "Owned", "D": ""}], _CONFIG
    )

    assert items == []


async def test_build_csv_preview_flags_existing_entry_as_duplicate_with_diffs(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    existing = await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user.id,
            title="Celeste",
            genre="Roguelike",
            platform="Switch",
            status="In Progress",
            owned=True,
            interest=5,
        ),
    )

    async def fake_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": "Finished"}],
        _CONFIG,
    )

    assert len(items[0].duplicates) == 1
    duplicate = items[0].duplicates[0]
    assert duplicate.backlog_entry_id == existing.backlog_entry_id
    diff_fields = {diff.field for diff in duplicate.diffs}
    assert "genre" in diff_fields
    assert "platform" in diff_fields
    assert "status" in diff_fields


async def test_build_csv_preview_formats_owned_diff_as_yes_no(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Renders through the same FieldDiffList component as the Creation
    Tool's duplicate dialog, which formats booleans as Yes/No - a bare
    str(bool) here ("True"/"False") would look inconsistent next to it."""
    user = await _make_user(session)
    await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user.id,
            title="Celeste",
            genre="Platformer",
            platform="PC",
            status="Completed",
            owned=False,
            interest=5,
        ),
    )

    async def fake_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": "Finished"}],
        _CONFIG,
    )

    owned_diff = next(diff for diff in items[0].duplicates[0].diffs if diff.field == "owned")
    assert owned_diff.existing == "No"
    assert owned_diff.proposed == "Yes"


async def test_build_csv_preview_treats_equal_playtime_with_different_precision_as_no_diff(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    await backlog_entry_repo.create_backlog_entry(
        session,
        CreateBacklogEntryParams(
            user_id=user.id,
            title="Celeste",
            genre="Platformer",
            platform="PC",
            status="Completed",
            owned=True,
            interest=5,
            playtime=Decimal("12.50"),
        ),
    )

    async def fake_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": "Finished", "E": "12.5"}],
        _CONFIG,
    )

    diff_fields = {diff.field for diff in items[0].duplicates[0].diffs}
    assert "playtime" not in diff_fields


async def test_build_csv_preview_uses_igdb_match_when_credentials_given(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        return [_igdb_result(title)]

    monkeypatch.setattr(preview.game_service, "search", fake_igdb_search)
    _stub_igdb_token(monkeypatch)
    monkeypatch.setattr(
        preview, "search_game_on_hltb", lambda title: pytest.fail("HLTB should not be used")
    )

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert items[0].image_link == "https://example.com/igdb-cover.jpg"
    assert items[0].main_time == Decimal("10.0")
    assert items[0].matched is True


async def test_build_csv_preview_carries_igdb_description_through_to_submit(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        return [_igdb_result(title, description="Help Madeline survive her inner journey.")]

    monkeypatch.setattr(preview.game_service, "search", fake_igdb_search)
    _stub_igdb_token(monkeypatch)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert items[0].description == "Help Madeline survive her inner journey."

    result = await preview.submit_csv_entries(
        session,
        user.id,
        [
            preview.SubmitCsvEntry(
                title=items[0].title,
                genre=items[0].genre,
                platform=items[0].platform,
                status=items[0].status,
                owned=items[0].owned,
                description=items[0].description,
            )
        ],
    )

    assert result.created[0].description == "Help Madeline survive her inner journey."


async def test_build_csv_preview_carries_igdb_trailer_through_to_submit(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    trailer = "https://www.youtube.com/watch?v=abc123DEF45"

    async def fake_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        return [_igdb_result(title, trailer_url=trailer)]

    monkeypatch.setattr(preview.game_service, "search", fake_igdb_search)
    _stub_igdb_token(monkeypatch)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert items[0].trailer_link == trailer

    result = await preview.submit_csv_entries(
        session,
        user.id,
        [
            preview.SubmitCsvEntry(
                title=items[0].title,
                genre=items[0].genre,
                platform=items[0].platform,
                status=items[0].status,
                owned=items[0].owned,
                trailer_link=items[0].trailer_link,
            )
        ],
    )

    assert result.created[0].trailer_link == trailer


async def test_build_csv_preview_retries_igdb_after_a_transient_error(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A single-title lookup outside a big import never hits this path,
    but 1000+ concurrent rows against IGDB's rate limit can - a
    transient failure used to permanently mark the row unmatched with
    no retry."""
    user = await _make_user(session)
    call_count = 0

    async def flaky_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        nonlocal call_count
        call_count += 1
        if call_count < 3:
            request = httpx.Request("GET", "https://api.igdb.com")
            raise httpx.HTTPStatusError(
                "429", request=request, response=httpx.Response(429, request=request)
            )
        return [_igdb_result(title)]

    monkeypatch.setattr(preview.game_service, "search", flaky_igdb_search)
    _stub_igdb_token(monkeypatch)
    monkeypatch.setattr(preview, "_MATCH_RETRY_BACKOFF_SECONDS", 0.01)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert call_count == 3
    assert items[0].matched is True
    assert items[0].image_link == "https://example.com/igdb-cover.jpg"


async def test_build_csv_preview_does_not_retry_a_non_transient_igdb_error(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A 401 (e.g. credentials that were valid at the preflight check but
    got revoked mid-import) won't succeed on retry - falls back to
    HowLongToBeat after a single attempt instead of burning through
    _MATCH_RETRY_ATTEMPTS on something that can't change."""
    user = await _make_user(session)
    call_count = 0

    async def unauthorized_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        nonlocal call_count
        call_count += 1
        request = httpx.Request("GET", "https://api.igdb.com")
        raise httpx.HTTPStatusError(
            "401", request=request, response=httpx.Response(401, request=request)
        )

    monkeypatch.setattr(preview.game_service, "search", unauthorized_igdb_search)
    _stub_igdb_token(monkeypatch)
    monkeypatch.setattr(preview, "_MATCH_RETRY_BACKOFF_SECONDS", 0.01)

    async def fake_hltb_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_hltb_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert call_count == 1
    assert items[0].image_link == "https://example.com/cover.jpg"


async def test_build_csv_preview_falls_back_to_hltb_without_igdb_credentials(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    monkeypatch.setattr(
        preview.game_service, "search", lambda *a, **kw: pytest.fail("IGDB should not be used")
    )

    async def fake_hltb_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_hltb_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=None,
    )

    assert items[0].image_link == "https://example.com/cover.jpg"


async def test_build_csv_preview_falls_back_to_hltb_once_for_invalid_igdb_credentials(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Invalid IGDB credentials must be discovered once, up front, and
    every row should then skip straight to HowLongToBeat - not have
    each row independently retry the same doomed IGDB auth failure."""
    user = await _make_user(session)
    token_attempts = 0

    async def failing_get_valid_token(client_id: str, client_secret: str) -> str:
        nonlocal token_attempts
        token_attempts += 1
        raise RuntimeError("Failed to generate IGDB access token")

    monkeypatch.setattr(preview.game_service, "get_valid_token", failing_get_valid_token)
    monkeypatch.setattr(
        preview.game_service, "search", lambda *a, **kw: pytest.fail("IGDB should not be used")
    )

    async def fake_hltb_search(title: str) -> list[HltbResultData]:
        return [_hltb_result(title)]

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_hltb_search)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [
            {"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""},
            {"A": "Hades", "B": "Roguelike", "C": "Owned", "D": ""},
        ],
        _CONFIG,
        igdb_credentials=("bad-client-id", "bad-client-secret"),
    )

    assert token_attempts == 1
    assert all(item.image_link == "https://example.com/cover.jpg" for item in items)


async def test_build_csv_preview_uses_igdb_genre_when_sheet_says_yes(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        return [_igdb_result(title, genres=["Survival", "Sandbox"])]

    monkeypatch.setattr(preview.game_service, "search", fake_igdb_search)
    _stub_igdb_token(monkeypatch)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Ark", "B": "Yes", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert items[0].genre == "Survival, Sandbox"


async def test_build_csv_preview_skips_igdb_lookups_not_needed_for_a_csv_row(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    calls: list[dict[str, object]] = []

    async def fake_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        calls.append(kwargs)
        return [_igdb_result(title)]

    monkeypatch.setattr(preview.game_service, "search", fake_igdb_search)
    _stub_igdb_token(monkeypatch)

    await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert calls == [
        {
            "limit": 1,
            "include_genres": False,
            "include_platforms": False,
            "include_publisher": False,
        }
    ]


async def test_build_csv_preview_keeps_sheet_genre_when_not_a_placeholder(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_igdb_search(
        title: str,
        client_id: str,
        client_secret: str,
        steamgriddb_api_key: str | None,
        **kwargs: object,
    ) -> list[EnrichedResult]:
        return [_igdb_result(title, genres=["Survival"])]

    monkeypatch.setattr(preview.game_service, "search", fake_igdb_search)
    _stub_igdb_token(monkeypatch)

    items = await preview.build_csv_preview(
        session,
        user.id,
        [{"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""}],
        _CONFIG,
        igdb_credentials=("client-id", "client-secret"),
    )

    assert items[0].genre == "Platformer"


async def test_build_csv_preview_reports_progress(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)

    async def fake_search(title: str) -> list[HltbResultData]:
        return []

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_search)

    progress_calls: list[tuple[int, int]] = []

    async def on_progress(processed: int, total: int) -> None:
        progress_calls.append((processed, total))

    await preview.build_csv_preview(
        session,
        user.id,
        [
            {"A": "Celeste", "B": "Platformer", "C": "Owned", "D": ""},
            {"A": "Hades", "B": "Roguelike", "C": "Owned", "D": ""},
        ],
        _CONFIG,
        on_progress=on_progress,
    )

    assert progress_calls == [(1, 2), (2, 2)]


async def test_build_csv_preview_matches_games_concurrently(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Regression test: matching used to run strictly sequentially, one
    HowLongToBeat/IGDB round-trip (each several seconds of network
    latency) per row - for a 1000+ row sheet that meant an hour-plus
    preview. Matching now runs with bounded concurrency instead."""
    user = await _make_user(session)
    in_flight = 0
    max_in_flight = 0

    async def fake_search(title: str) -> list[HltbResultData]:
        nonlocal in_flight, max_in_flight
        in_flight += 1
        max_in_flight = max(max_in_flight, in_flight)
        await asyncio.sleep(0.05)
        in_flight -= 1
        return []

    monkeypatch.setattr(preview, "search_game_on_hltb", fake_search)

    records = [{"A": f"Game {i}", "B": "RPG", "C": "Owned", "D": ""} for i in range(8)]
    await preview.build_csv_preview(session, user.id, records, _CONFIG)

    assert max_in_flight > 1


async def test_submit_csv_entries_creates_confirmed_rows(session: AsyncSession) -> None:
    user = await _make_user(session)

    result = await preview.submit_csv_entries(
        session,
        user.id,
        [
            preview.SubmitCsvEntry(
                title="Celeste",
                genre="Platformer",
                platform=["PC"],
                status="Completed",
                owned=True,
                playtime=Decimal("12.5"),
                review_stars=9,
                note="Great",
                review="Loved the ending",
                completed_at=_COMPLETED_AT,
                image_link="https://example.com/cover.jpg",
                main_time=Decimal("8.5"),
            )
        ],
    )

    assert len(result.created) == 1
    assert result.created[0].title == "Celeste"
    assert result.created[0].platform == "PC"
    assert result.created[0].completed_at == _COMPLETED_AT
    assert result.created[0].review == "Loved the ending"
    assert result.skipped == []

    entries = await backlog_entry_repo.get_backlog_entries_by_user(session, user.id)
    assert len(entries) == 1


async def test_submit_csv_entries_clears_completed_at_for_a_non_completed_status(
    session: AsyncSession,
) -> None:
    """A sheet row can carry a completion date alongside a status the
    sheet's own normalization didn't map to "Completed" (e.g. a status
    qualifier note like "Playing (Backseat)") - passing completed_at
    through unconditionally would create a state the DB trigger's own
    invariant (no completion date on a non-Completed row) forbids on
    every subsequent UPDATE."""
    user = await _make_user(session)

    result = await preview.submit_csv_entries(
        session,
        user.id,
        [
            preview.SubmitCsvEntry(
                title="Celeste",
                genre="Platformer",
                platform=["PC"],
                status="In Progress",
                owned=True,
                completed_at=_COMPLETED_AT,
            )
        ],
    )

    assert result.created[0].completed_at is None


async def test_submit_csv_entries_skips_conflicting_rows_without_failing_the_rest(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = await _make_user(session)
    call_count = 0

    async def fake_create(session: AsyncSession, params: CreateBacklogEntryParams) -> object:
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            raise ConflictError("already exists")
        return await backlog_entry_repo.create_backlog_entry(session, params)

    monkeypatch.setattr(preview, "create_backlog_entry", fake_create)

    result = await preview.submit_csv_entries(
        session,
        user.id,
        [
            preview.SubmitCsvEntry(
                title="Celeste",
                genre="Platformer",
                platform=["PC"],
                status="Not Started",
                owned=True,
            ),
            preview.SubmitCsvEntry(
                title="Hades", genre="Roguelike", platform=["PC"], status="Not Started", owned=True
            ),
        ],
    )

    assert len(result.created) == 1
    assert result.created[0].title == "Hades"
    assert len(result.skipped) == 1
    assert result.skipped[0].title == "Celeste"
    assert result.skipped[0].reason == "already exists"


async def test_submit_csv_entries_reports_a_generic_reason_for_a_database_error(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """DatabaseError's message embeds the wrapped driver/SQL cause -
    fine for the server log, not for a client-facing skip reason."""
    user = await _make_user(session)

    async def fake_create(session: AsyncSession, params: CreateBacklogEntryParams) -> object:
        raise DatabaseError("create_backlog_entry", cause="duplicate key value violates ...")

    monkeypatch.setattr(preview, "create_backlog_entry", fake_create)

    result = await preview.submit_csv_entries(
        session,
        user.id,
        [
            preview.SubmitCsvEntry(
                title="Celeste",
                genre="Platformer",
                platform=["PC"],
                status="Not Started",
                owned=True,
            )
        ],
    )

    assert result.created == []
    assert result.skipped[0].reason == "Database error - see server logs for details"

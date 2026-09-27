import asyncio
from collections.abc import Awaitable, Callable
from datetime import datetime
from decimal import Decimal, InvalidOperation

import httpx
import msgspec
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.csv.field_parsing import clamp_rating, parse_completed_at
from backlog_manager_backend.csv.parse_csv import ColumnConfig, CSVRecord, _safe_string
from backlog_manager_backend.csv.platform_mapping import PlatformMapping, normalize_platform
from backlog_manager_backend.csv.status_mapping import StatusMapping, normalize_status
from backlog_manager_backend.errors import (
    ConflictError,
    DatabaseError,
    NotFoundError,
    ValidationError,
)
from backlog_manager_backend.integrations.howlongtobeat import search_game_on_hltb
from backlog_manager_backend.repositories.backlog_entry_repo import (
    create_backlog_entry,
    get_backlog_entry_duplicates,
)
from backlog_manager_backend.schemas.backlog_entry import BacklogEntry, CreateBacklogEntryParams
from backlog_manager_backend.services import game_service

logger = structlog.get_logger()

ProgressCallback = Callable[[int, int], Awaitable[None]]

_DIFF_FIELDS = (
    "genre",
    "platform",
    "status",
    "owned",
    "playtime",
    "review_stars",
    "note",
    "completed_at",
)


class FieldDiff(msgspec.Struct):
    field: str
    existing: str
    proposed: str


class DuplicateMatch(msgspec.Struct):
    backlog_entry_id: int
    title: str
    diffs: list[FieldDiff]


class CsvPreviewItem(msgspec.Struct):
    """One row of the CSV-import preview table - what submitting this
    row would create, before anything is written. `matched` is
    False when neither IGDB nor HowLongToBeat found the title; the row
    can still be submitted, just without cover/time enrichment."""

    row_index: int
    title: str
    genre: str
    platform: list[str]
    status: str
    owned: bool
    playtime: Decimal | None = None
    review_stars: int | None = None
    note: str | None = None
    review: str | None = None
    completed_at: datetime | None = None
    image_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None
    matched: bool = False
    duplicates: list[DuplicateMatch] = []


class SubmitCsvEntry(msgspec.Struct):
    title: str
    genre: str
    platform: list[str]
    status: str
    owned: bool
    playtime: Decimal | None = None
    review_stars: int | None = None
    note: str | None = None
    review: str | None = None
    completed_at: datetime | None = None
    image_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None


class _GameMatch(msgspec.Struct):
    image_url: str | None
    main_story: float
    main_story_with_extras: float
    completionist: float
    genres: list[str] = []


_GENRE_PLACEHOLDERS = {"yes", "y", "no", "n"}

_MATCH_CONCURRENCY = 4


def _needs_genre_fallback(genre_raw: str) -> bool:
    return not genre_raw or genre_raw.lower() in _GENRE_PLACEHOLDERS


async def _match_game(
    title: str,
    igdb_credentials: tuple[str, str] | None,
    steamgriddb_api_key: str | None,
    need_genres: bool,
) -> _GameMatch | None:
    """Best-effort game match for one CSV row. Prefers the enriched IGDB
    search (`game_service.search`) when the caller has IGDB credentials
    configured - it has genre data HowLongToBeat doesn't, and a
    SteamGridDB-backed cover fallback that finds art for far more
    non-Steam/fan games than HowLongToBeat alone. Falls back to a plain
    HowLongToBeat search when IGDB isn't configured, or turned up
    nothing for the title. Requests only the top match with no
    platform/publisher data, and skips genres too when `need_genres` is
    False, since none of that is used here."""
    if igdb_credentials is not None:
        client_id, client_secret = igdb_credentials
        try:
            igdb_results = await game_service.search(
                title,
                client_id,
                client_secret,
                steamgriddb_api_key,
                limit=1,
                include_genres=need_genres,
                include_platforms=False,
                include_publisher=False,
            )
        except (httpx.HTTPError, RuntimeError):
            igdb_results = []
        if igdb_results:
            match = igdb_results[0]
            return _GameMatch(
                image_url=match.image_url,
                main_story=match.main_story,
                main_story_with_extras=match.main_story_with_extras,
                completionist=match.completionist,
                genres=match.genres,
            )

    hltb_results = await search_game_on_hltb(title)
    if hltb_results:
        match = hltb_results[0]
        return _GameMatch(
            image_url=match.image_url,
            main_story=match.main_story,
            main_story_with_extras=match.main_story_with_extras,
            completionist=match.completionist,
        )

    return None


async def _match_all_games(
    rows: list[tuple[str, bool]],
    igdb_credentials: tuple[str, str] | None,
    steamgriddb_api_key: str | None,
    on_row_matched: Callable[[], Awaitable[None]] | None,
) -> list[_GameMatch | None]:
    """Resolves every row's match concurrently, bounded by
    _MATCH_CONCURRENCY - the DB duplicate-check that follows each match
    stays sequential (a single AsyncSession isn't safe to use from
    multiple coroutines at once), but the network-bound matching itself
    has no such constraint. `asyncio.gather` preserves input order in
    its result list regardless of which title's lookup finishes first,
    so callers can zip it back against `rows` unchanged. Each row is
    (title, need_genres) - see _match_game."""
    semaphore = asyncio.Semaphore(_MATCH_CONCURRENCY)

    async def match_one(title: str, need_genres: bool) -> _GameMatch | None:
        async with semaphore:
            result = await _match_game(title, igdb_credentials, steamgriddb_api_key, need_genres)
        if on_row_matched:
            await on_row_matched()
        return result

    return await asyncio.gather(*(match_one(title, need_genres) for title, need_genres in rows))


def _parse_decimal(raw: str) -> Decimal | None:
    trimmed = raw.strip()
    if not trimmed:
        return None
    try:
        return Decimal(trimmed)
    except InvalidOperation:
        return None


def _join_note(*parts: str | None) -> str | None:
    joined = "; ".join(part for part in parts if part)
    return joined or None


def _diff_entry(
    existing: BacklogEntry,
    genre: str,
    platform: list[str],
    status: str,
    owned: bool,
    playtime: Decimal | None,
    review_stars: int | None,
    note: str | None,
    completed_at: datetime | None,
) -> list[FieldDiff]:
    existing_platform = [p for p in existing.platform.split(", ") if p]
    proposed_values = {
        "genre": (existing.genre, genre),
        "platform": (", ".join(existing_platform), ", ".join(platform)),
        "status": (existing.status, status),
        "owned": (str(existing.owned), str(owned)),
        "playtime": (
            str(existing.playtime) if existing.playtime is not None else "",
            str(playtime) if playtime is not None else "",
        ),
        "review_stars": (
            str(existing.review_stars) if existing.review_stars is not None else "",
            str(review_stars) if review_stars is not None else "",
        ),
        "note": (existing.note or "", note or ""),
        "completed_at": (
            existing.completed_at.date().isoformat() if existing.completed_at else "",
            completed_at.date().isoformat() if completed_at else "",
        ),
    }
    return [
        FieldDiff(field=field, existing=existing_value, proposed=proposed_value)
        for field in _DIFF_FIELDS
        for existing_value, proposed_value in [proposed_values[field]]
        if existing_value != proposed_value
    ]


async def _find_duplicates(
    session: AsyncSession,
    user_id: int,
    title: str,
    genre: str,
    platform: list[str],
    status: str,
    owned: bool,
    playtime: Decimal | None,
    review_stars: int | None,
    note: str | None,
    completed_at: datetime | None,
) -> list[DuplicateMatch]:
    existing_entries = await get_backlog_entry_duplicates(session, user_id, title, None)
    return [
        DuplicateMatch(
            backlog_entry_id=existing.backlog_entry_id,
            title=existing.title,
            diffs=_diff_entry(
                existing, genre, platform, status, owned, playtime, review_stars, note, completed_at
            ),
        )
        for existing in existing_entries
    ]


class _ParsedRow(msgspec.Struct):
    row_index: int
    title: str
    genre_raw: str
    platform_mapping: PlatformMapping
    status_mapping: StatusMapping
    playtime: Decimal | None
    review_stars: int | None
    completed_at: datetime | None
    note: str | None
    review: str | None


async def build_csv_preview(
    session: AsyncSession,
    user_id: int,
    records: list[CSVRecord],
    config: ColumnConfig,
    headers: dict[str, str] | None = None,
    igdb_credentials: tuple[str, str] | None = None,
    steamgriddb_api_key: str | None = None,
    on_progress: ProgressCallback | None = None,
) -> list[CsvPreviewItem]:
    """Parses+matches every CSV row against IGDB/HowLongToBeat and the
    user's existing backlog without writing anything - the confirmed,
    possibly-edited result of this preview is what submit_csv_entries
    below actually creates. Rows without a title are skipped outright:
    there's nothing to preview or submit for them. `headers` (column
    letter -> header text) labels the note columns so a short
    yes/no-style answer (e.g. `Stunner?` = `Yes`) keeps its context
    once merged into one note field instead of becoming a bare "Yes".

    Parsing (fast, local) and matching (slow, network-bound, run with
    bounded concurrency via _match_all_games) happen in one pass over
    `records` each; the DB duplicate-check that needs each row's match
    result runs in a final sequential pass, since a single AsyncSession
    can't be used from multiple coroutines concurrently."""
    headers = headers or {}
    total = len(records)
    processed = 0

    async def tick() -> None:
        nonlocal processed
        processed += 1
        if on_progress:
            await on_progress(processed, total)

    parsed_rows: list[_ParsedRow] = []
    for row_index, record in enumerate(records, start=1):
        title = _safe_string(record.get(config.title_column), "").strip()
        if not title:
            await tick()
            continue

        genre_raw = _safe_string(record.get(config.genre_column), "").strip()

        platform_raw = _safe_string(record.get(config.platform_column), "").strip()
        platform_mapping = (
            normalize_platform(platform_raw) if platform_raw else PlatformMapping(platform=[], owned=True)
        )

        status_mapping = normalize_status(_safe_string(record.get(config.status_column), ""))

        playtime = (
            _parse_decimal(_safe_string(record.get(config.playtime_column), ""))
            if config.playtime_column
            else None
        )
        review_stars = (
            clamp_rating(_safe_string(record.get(config.rating_column), ""))
            if config.rating_column
            else None
        )
        completed_at = (
            parse_completed_at(_safe_string(record.get(config.completed_at_column), ""))
            if config.completed_at_column
            else None
        )

        note_parts = [status_mapping.note, platform_mapping.note]
        for column in config.note_columns:
            value = _safe_string(record.get(column), "").strip()
            if value:
                note_parts.append(f"{headers.get(column, column)}: {value}")
        note = _join_note(*note_parts)

        review_parts = [
            _safe_string(record.get(column), "").strip() for column in config.review_columns
        ]
        review = _join_note(*review_parts)

        parsed_rows.append(
            _ParsedRow(
                row_index=row_index,
                title=title,
                genre_raw=genre_raw,
                platform_mapping=platform_mapping,
                status_mapping=status_mapping,
                playtime=playtime,
                review_stars=review_stars,
                completed_at=completed_at,
                note=note,
                review=review,
            )
        )

    matches = await _match_all_games(
        [(row.title, _needs_genre_fallback(row.genre_raw)) for row in parsed_rows],
        igdb_credentials,
        steamgriddb_api_key,
        tick,
    )

    items: list[CsvPreviewItem] = []
    for row, game_match in zip(parsed_rows, matches, strict=True):
        genre = row.genre_raw
        if _needs_genre_fallback(row.genre_raw) and game_match and game_match.genres:
            genre = ", ".join(game_match.genres)
        genre = genre or "Unknown"

        duplicates = await _find_duplicates(
            session,
            user_id,
            row.title,
            genre,
            row.platform_mapping.platform,
            row.status_mapping.status,
            row.platform_mapping.owned,
            row.playtime,
            row.review_stars,
            row.note,
            row.completed_at,
        )

        items.append(
            CsvPreviewItem(
                row_index=row.row_index,
                title=row.title,
                genre=genre,
                platform=row.platform_mapping.platform,
                status=row.status_mapping.status,
                owned=row.platform_mapping.owned,
                playtime=row.playtime,
                review_stars=row.review_stars,
                note=row.note,
                review=row.review,
                completed_at=row.completed_at,
                image_link=game_match.image_url if game_match else None,
                main_time=Decimal(str(game_match.main_story)) if game_match else None,
                main_plus_extra_time=(
                    Decimal(str(game_match.main_story_with_extras)) if game_match else None
                ),
                completion_time=Decimal(str(game_match.completionist)) if game_match else None,
                matched=game_match is not None,
                duplicates=duplicates,
            )
        )

    return items


async def submit_csv_entries(
    session: AsyncSession,
    user_id: int,
    entries: list[SubmitCsvEntry],
    on_progress: ProgressCallback | None = None,
) -> list[BacklogEntry]:
    """Creates one backlog entry per confirmed preview row. Mirrors
    steam_service.import_library's per-row error handling: a
    ConflictError from the DB's unique constraint (steam_app_id-based,
    rarely hit by CSV rows) is treated as already-imported and skipped
    rather than failing the whole submit, and the same goes for any
    other per-row failure - one bad row must not discard every row
    after it."""
    created: list[BacklogEntry] = []
    total = len(entries)

    for index, entry in enumerate(entries, start=1):
        try:
            created.append(
                await create_backlog_entry(
                    session,
                    CreateBacklogEntryParams(
                        user_id=user_id,
                        title=entry.title,
                        genre=entry.genre,
                        platform=", ".join(entry.platform),
                        status=entry.status,
                        owned=entry.owned,
                        interest=5,
                        image_link=entry.image_link,
                        main_time=entry.main_time,
                        main_plus_extra_time=entry.main_plus_extra_time,
                        completion_time=entry.completion_time,
                        playtime=entry.playtime,
                        review_stars=entry.review_stars,
                        note=entry.note,
                        review=entry.review,
                        completed_at=entry.completed_at,
                    ),
                )
            )
        except (ConflictError, NotFoundError, ValidationError, DatabaseError) as error:
            logger.warning("Skipping CSV row during submit", title=entry.title, error=str(error))
        if on_progress:
            await on_progress(index, total)

    return created

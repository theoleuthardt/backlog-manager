import csv
import io
import string
from decimal import Decimal

import msgspec
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import (
    ConflictError,
    DatabaseError,
    NotFoundError,
    ValidationError,
)
from backlog_manager_backend.integrations.howlongtobeat import search_game_on_hltb
from backlog_manager_backend.repositories.backlog_entry_repo import create_backlog_entry
from backlog_manager_backend.schemas.backlog_entry import CreateBacklogEntryParams

logger = structlog.get_logger()

CSVRecord = dict[str, object]

_COLUMN_KEYS = list(string.ascii_uppercase)


class ColumnConfig(msgspec.Struct):
    title_column: str
    genre_column: str
    platform_column: str
    status_column: str


class MissingGame(msgspec.Struct):
    title: str
    genre: str
    platform: str
    status: str


class RecordError(msgspec.Struct):
    title: str
    error: str


class ImportResult(msgspec.Struct):
    success: int = 0
    failed: int = 0
    errors: list[RecordError] = []
    missing_games: list[MissingGame] = []


def parse_csv_content(file_content: str) -> list[CSVRecord]:
    reader = csv.reader(io.StringIO(file_content))
    records: list[CSVRecord] = []
    for row in reader:
        if not row or (len(row) == 1 and row[0] == ""):
            continue
        record: CSVRecord = {}
        for index, value in enumerate(row):
            if index < len(_COLUMN_KEYS):
                record[_COLUMN_KEYS[index]] = value
        records.append(record)
    return records


def _safe_string(value: object, default: str = "") -> str:
    if isinstance(value, str):
        return value
    if value is None:
        return default
    if isinstance(value, (int, float, bool)):
        return str(value)
    return default


_import_progress: dict[str, int] = {}
_import_cancel_flags: dict[str, bool] = {}


def get_import_progress(session_id: str) -> int:
    return _import_progress.get(session_id, 0)


def set_import_progress(session_id: str, processed: int) -> None:
    _import_progress[session_id] = processed


def clear_import_progress(session_id: str) -> None:
    _import_progress.pop(session_id, None)
    _import_cancel_flags.pop(session_id, None)


def set_cancel_flag(session_id: str, cancelled: bool) -> None:
    if cancelled:
        _import_cancel_flags[session_id] = True
    else:
        _import_cancel_flags.pop(session_id, None)


def get_cancel_flag(session_id: str) -> bool:
    return _import_cancel_flags.get(session_id, False)


def is_cancelled(session_id: str) -> bool:
    return get_cancel_flag(session_id)


async def import_backlog_entries_from_csv(
    session: AsyncSession,
    user_id: int,
    records: list[CSVRecord],
    config: ColumnConfig,
    session_id: str | None = None,
) -> ImportResult:
    result = ImportResult(errors=[], missing_games=[])
    processed_count = 0

    for record in records:
        if session_id and is_cancelled(session_id):
            logger.info(
                "Import cancelled",
                processed=processed_count + 1,
                total=len(records),
            )
            break

        title = _safe_string(record.get(config.title_column), "").strip()

        if not title:
            result.failed += 1
            result.errors.append(
                RecordError(
                    title="Unknown",
                    error=f"Title (column {config.title_column}) is required",
                )
            )
            processed_count += 1
            if session_id:
                set_import_progress(session_id, processed_count)
            continue

        search_results = await search_game_on_hltb(title)
        game_data = search_results[0] if search_results else None

        if game_data is None:
            result.missing_games.append(
                MissingGame(
                    title=title,
                    genre=_safe_string(record.get(config.genre_column), "Unknown"),
                    platform=_safe_string(record.get(config.platform_column), "Unknown"),
                    status=_safe_string(record.get(config.status_column), "Not Started"),
                )
            )
            processed_count += 1
            if session_id:
                set_import_progress(session_id, processed_count)
            continue

        try:
            await create_backlog_entry(
                session,
                CreateBacklogEntryParams(
                    user_id=user_id,
                    title=title,
                    genre=_safe_string(record.get(config.genre_column), "Unknown"),
                    platform=_safe_string(record.get(config.platform_column), "Unknown"),
                    status="Not Started",
                    owned=True,
                    interest=5,
                    image_link=game_data.image_url,
                    main_time=Decimal(str(game_data.main_story)),
                    main_plus_extra_time=Decimal(str(game_data.main_story_with_extras)),
                    completion_time=Decimal(str(game_data.completionist)),
                ),
            )
            result.success += 1
        except (NotFoundError, ConflictError, ValidationError, DatabaseError) as error:
            result.failed += 1
            result.errors.append(RecordError(title=title, error=str(error)))
        finally:
            processed_count += 1
            if session_id:
                set_import_progress(session_id, processed_count)

    return result

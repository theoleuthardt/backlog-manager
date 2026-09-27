import csv
import io
import string

import msgspec

CSVRecord = dict[str, object]

_COLUMN_KEYS = list(string.ascii_uppercase)


class ColumnConfig(msgspec.Struct):
    title_column: str
    genre_column: str
    platform_column: str
    status_column: str
    playtime_column: str | None = None
    rating_column: str | None = None
    completed_at_column: str | None = None
    note_columns: list[str] = []
    review_columns: list[str] = []


def extract_csv_headers(file_content: str) -> dict[str, str]:
    """The first row's cell text per column letter (e.g. {"A": "Game",
    "B": "Genre"}) - lets the import UI label each column picker with
    its real header instead of a blind spreadsheet letter."""
    reader = csv.reader(io.StringIO(file_content))
    try:
        header_row = next(reader)
    except StopIteration:
        return {}
    return {
        _COLUMN_KEYS[index]: value
        for index, value in enumerate(header_row)
        if index < len(_COLUMN_KEYS)
    }


def parse_csv_content(file_content: str) -> list[CSVRecord]:
    """Splits every row after the header row into a letter-keyed dict.
    The first row is always treated as a header (matching how every
    spreadsheet export used against this feature actually looks) and
    never becomes a data record - see extract_csv_headers for reading
    it back out."""
    reader = csv.reader(io.StringIO(file_content))
    records: list[CSVRecord] = []
    for row_index, row in enumerate(reader):
        if row_index == 0:
            continue
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

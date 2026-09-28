import re
from datetime import UTC, datetime

from backlog_manager_backend.schemas.backlog_entry import MAX_REVIEW_STARS

_MONTH_YEAR_RE = re.compile(r"^(?P<month>\d{1,2})\.(?P<year>\d{4})$")


def clamp_rating(raw: str) -> int | None:
    """MYY-sheet ratings go above the app's 10-star max - clamp rather
    than reject, since the relative ordering (a 10 beats an 8) still
    means the same thing either way."""
    trimmed = raw.strip()
    if not trimmed or trimmed == "-":
        return None
    try:
        value = int(trimmed)
    except ValueError:
        return None
    return min(value, MAX_REVIEW_STARS)


def parse_completed_at(raw: str) -> datetime | None:
    """Parses the sheet's `M.YYYY` completion date (day is unknown, so
    it defaults to the 1st of the month) into a naive datetime - the
    "CompletedAt" column is TIMESTAMP WITHOUT TIME ZONE, and a sheet
    month/year has no timezone of its own to begin with. `IDK` and
    blank cells both mean "no date recorded", not an error; a
    syntactically valid but out-of-range year (e.g. "7.0000") is
    likewise treated as unparseable rather than raising."""
    trimmed = raw.strip()
    if not trimmed or trimmed.upper() == "IDK":
        return None

    match = _MONTH_YEAR_RE.match(trimmed)
    if not match:
        return None

    month = int(match.group("month"))
    year = int(match.group("year"))
    if not 1 <= month <= 12:
        return None
    try:
        return datetime(year, month, 1, tzinfo=UTC).replace(tzinfo=None)
    except ValueError:
        return None

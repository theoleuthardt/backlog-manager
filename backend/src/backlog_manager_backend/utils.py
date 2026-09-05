from datetime import UTC, datetime


def now_truncated_to_minute() -> datetime:
    """Naive UTC timestamp truncated to the minute, matching the existing
    SQL DATE_TRUNC('minute', CURRENT_TIMESTAMP) used for "UpdatedAt" columns
    (TIMESTAMP WITHOUT TIME ZONE, hence naive rather than tz-aware)."""
    return datetime.now(UTC).replace(second=0, microsecond=0, tzinfo=None)

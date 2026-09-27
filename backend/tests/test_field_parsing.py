from datetime import UTC, datetime

from backlog_manager_backend.csv.field_parsing import clamp_rating, parse_completed_at


def _naive(*args: int) -> datetime:
    return datetime(*args, tzinfo=UTC).replace(tzinfo=None)


def test_clamp_rating_passes_through_values_within_range() -> None:
    assert clamp_rating("7") == 7
    assert clamp_rating("10") == 10
    assert clamp_rating("1") == 1


def test_clamp_rating_clamps_values_above_ten() -> None:
    assert clamp_rating("11") == 10


def test_clamp_rating_returns_none_for_empty_or_placeholder() -> None:
    assert clamp_rating("") is None
    assert clamp_rating("-") is None
    assert clamp_rating("  ") is None


def test_clamp_rating_returns_none_for_non_numeric() -> None:
    assert clamp_rating("n/a") is None


def test_parse_completed_at_parses_month_dot_year() -> None:
    assert parse_completed_at("7.2026") == _naive(2026, 7, 1)
    assert parse_completed_at("12.2025") == _naive(2025, 12, 1)


def test_parse_completed_at_returns_none_for_idk() -> None:
    assert parse_completed_at("IDK") is None
    assert parse_completed_at("idk") is None


def test_parse_completed_at_returns_none_for_empty() -> None:
    assert parse_completed_at("") is None
    assert parse_completed_at("   ") is None


def test_parse_completed_at_returns_none_for_invalid_month() -> None:
    assert parse_completed_at("13.2025") is None


def test_parse_completed_at_returns_none_for_unparseable_text() -> None:
    assert parse_completed_at("sometime last year") is None

import re

import msgspec

_STATUS_ALIASES = {
    "finished": "Completed",
    "playing": "In Progress",
    "dropped": "Dropped",
}

_STATUS_RE = re.compile(r"^(?P<base>[A-Za-z]+)\s*(\((?P<qualifier>[^)]+)\))?$")


class StatusMapping(msgspec.Struct):
    status: str
    note: str | None = None


def normalize_status(raw: str) -> StatusMapping:
    """Maps one MYY-sheet status cell onto the app's canonical statuses.
    Empty means "not yet played" in the sheet, not "unknown". A
    qualifier in parens (`Finished (Replay Needed)`, `Dropped (For
    now)`) still collapses to the canonical status - filtering/grouping
    relies on that being one of the fixed values - but the qualifier
    itself is kept as `note` rather than dropped."""
    trimmed = raw.strip()
    if not trimmed:
        return StatusMapping(status="Not Started")

    match = _STATUS_RE.match(trimmed)
    if match:
        canonical = _STATUS_ALIASES.get(match.group("base").lower())
        if canonical is not None:
            qualifier = match.group("qualifier")
            return StatusMapping(status=canonical, note=f"({qualifier})" if qualifier else None)

    return StatusMapping(status=trimmed)

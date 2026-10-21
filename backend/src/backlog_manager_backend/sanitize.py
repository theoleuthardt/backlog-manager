"""Sanitizing of every JSON request body before it is validated.

Text is NFC-normalized, invisible formatting characters (bidi overrides
and isolates, directional marks, zero-width spaces, word joiners, byte
order marks) and control characters other than tab and line breaks are
removed, and whitespace at the edges is trimmed. Punctuation is never
touched: queries use bound parameters, so `'`, `;` or `{}` are harmless
and stripping them would only change titles, reviews and names. The
zero-width joiner and non-joiner stay, since emoji sequences and several
scripts need them. Passwords are kept exactly as typed."""

import unicodedata
from typing import Any

from litestar import Request

_UNSANITIZED_KEYS = frozenset({"password"})
_INVISIBLE = (
    "\N{ARABIC LETTER MARK}",
    "\N{ZERO WIDTH SPACE}",
    "\N{LEFT-TO-RIGHT MARK}",
    "\N{RIGHT-TO-LEFT MARK}",
    "\N{LEFT-TO-RIGHT EMBEDDING}",
    "\N{RIGHT-TO-LEFT EMBEDDING}",
    "\N{POP DIRECTIONAL FORMATTING}",
    "\N{LEFT-TO-RIGHT OVERRIDE}",
    "\N{RIGHT-TO-LEFT OVERRIDE}",
    "\N{WORD JOINER}",
    "\N{LEFT-TO-RIGHT ISOLATE}",
    "\N{RIGHT-TO-LEFT ISOLATE}",
    "\N{FIRST STRONG ISOLATE}",
    "\N{POP DIRECTIONAL ISOLATE}",
    "\N{ZERO WIDTH NO-BREAK SPACE}",
)
_CONTROLS = [*range(0x20), *range(0x7F, 0xA0)]
_REMOVED = dict.fromkeys(
    [*map(ord, _INVISIBLE), *(code for code in _CONTROLS if chr(code) not in "\t\n\r")]
)


def sanitize_text(value: str) -> str:
    """`str.translate` keeps a 10 MiB body (a CSV import) well under a
    tenth of a second, so the event loop is not held up."""
    return unicodedata.normalize("NFC", value).translate(_REMOVED).strip()


def sanitize_tree(value: Any) -> Any:
    """Sanitizes every string in a decoded JSON value. Object keys are left
    as they are, and so is the value of any key named `password`."""
    if isinstance(value, str):
        return sanitize_text(value)
    if isinstance(value, list):
        return [sanitize_tree(item) for item in value]
    if isinstance(value, dict):
        return {
            key: item if key in _UNSANITIZED_KEYS else sanitize_tree(item)
            for key, item in value.items()
        }
    return value


class SanitizedRequest(Request):
    """The app's request class: `data` parameters are read through `json()`,
    so every JSON body reaches validation already sanitized."""

    async def json(self) -> Any:
        return sanitize_tree(await super().json())

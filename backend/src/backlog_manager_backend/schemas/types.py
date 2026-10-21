from typing import Annotated

import msgspec

HexColor = Annotated[str, msgspec.Meta(pattern=r"^#[0-9a-fA-F]{6}$")]
"""A plain #rrggbb colour. Colours end up in CSS on the client, so
anything freer-form (url(), expression(), ...) is rejected at the
boundary."""

YouTubeWatchUrl = Annotated[
    str, msgspec.Meta(pattern=r"^https://www\.youtube\.com/watch\?v=[A-Za-z0-9_-]{11}$")
]
"""A canonical `https://www.youtube.com/watch?v=<11-char id>` link, the
form IGDB's game_videos ids are stored as. The client turns it into an
embedded player, so anything else (other hosts, javascript: URLs) is
rejected at the boundary."""

WebUrl = Annotated[str, msgspec.Meta(pattern=r"^https?://\S+$", max_length=2000)]
"""An http(s) link. Links are opened by the client, so other schemes
(javascript:, file:, ...) are rejected at the boundary."""

Username = Annotated[str, msgspec.Meta(pattern=r"^[A-Za-z0-9_.-]{3,32}$(?!\n)")]
"""A username as it can be set: 3 to 32 letters, digits, `_`, `-` or
`.`. Anything else is rejected at the boundary rather than stripped, so
a stored name is always exactly what was sent. `(?!\n)` closes the gap
where Python's `$` also matches before a trailing newline. Only applies
when a name is set; names stored before this rule stay valid."""

UsernameQuery = Annotated[str, msgspec.Meta(min_length=1, max_length=50)]
"""A username looked up rather than set (e.g. a space invitation). Only
bounded by the column length, so names stored before the `Username`
rule can still be found."""

Email = Annotated[str, msgspec.Meta(pattern=r"^[^\s@]+@[^\s@]+\.[^\s@]+$(?!\n)", max_length=255)]
"""An e-mail address as it can be set: one `@`, a dot in the domain, no
whitespace (not even a trailing newline, see `Username`), at most the
255 characters of the column."""

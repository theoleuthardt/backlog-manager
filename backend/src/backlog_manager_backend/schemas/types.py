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

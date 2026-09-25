from typing import Annotated

import msgspec

HexColor = Annotated[str, msgspec.Meta(pattern=r"^#[0-9a-fA-F]{6}$")]
"""A plain #rrggbb colour. Colours end up in CSS on the client, so
anything freer-form (url(), expression(), ...) is rejected at the
boundary."""

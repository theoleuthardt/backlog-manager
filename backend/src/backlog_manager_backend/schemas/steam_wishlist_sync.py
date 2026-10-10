from datetime import datetime

import msgspec


class SteamWishlistChange(msgspec.Struct):
    """One game the automatic wishlist sync added to or removed from the
    backlog."""

    steam_app_id: int
    title: str
    image_link: str | None = None


class SteamWishlistSyncReport(msgspec.Struct):
    """What the automatic wishlist sync changed since the user last
    dismissed the report: `since` is the time of the first change and
    `updated_at` the time of the latest one, which a client sends back when
    it dismisses the report so changes that arrived meanwhile survive."""

    since: datetime | None = None
    updated_at: datetime | None = None
    added: list[SteamWishlistChange] = msgspec.field(default_factory=list)
    removed: list[SteamWishlistChange] = msgspec.field(default_factory=list)

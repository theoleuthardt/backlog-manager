from datetime import date, datetime
from decimal import Decimal

import msgspec


class BacklogEntry(msgspec.Struct):
    backlog_entry_id: int
    user_id: int
    title: str
    genre: str
    platform: str
    status: str
    owned: bool
    interest: int
    created_at: datetime
    updated_at: datetime
    release_date: date | None = None
    image_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None
    review_stars: int | None = None
    review: str | None = None
    note: str | None = None
    completed_at: datetime | None = None


class CreateBacklogEntryParams(msgspec.Struct):
    user_id: int
    title: str
    genre: str
    platform: str
    status: str
    owned: bool
    interest: int
    release_date: date | None = None
    image_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None
    review_stars: int | None = None
    review: str | None = None
    note: str | None = None


class UpdateBacklogEntryParams(msgspec.Struct):
    """Every optional field defaults to UNSET (field omitted from the
    update - leave unchanged), distinct from an explicit None (field
    provided as null - clear it). Using a plain None default for both
    would make it impossible to ever clear a nullable column such as
    review_stars or note."""

    backlog_entry_id: int
    title: str | msgspec.UnsetType = msgspec.UNSET
    genre: str | msgspec.UnsetType = msgspec.UNSET
    platform: str | msgspec.UnsetType = msgspec.UNSET
    status: str | msgspec.UnsetType = msgspec.UNSET
    owned: bool | msgspec.UnsetType = msgspec.UNSET
    interest: int | msgspec.UnsetType = msgspec.UNSET
    release_date: date | None | msgspec.UnsetType = msgspec.UNSET
    image_link: str | None | msgspec.UnsetType = msgspec.UNSET
    main_time: Decimal | None | msgspec.UnsetType = msgspec.UNSET
    main_plus_extra_time: Decimal | None | msgspec.UnsetType = msgspec.UNSET
    completion_time: Decimal | None | msgspec.UnsetType = msgspec.UNSET
    review_stars: int | None | msgspec.UnsetType = msgspec.UNSET
    review: str | None | msgspec.UnsetType = msgspec.UNSET
    note: str | None | msgspec.UnsetType = msgspec.UNSET


class GetEntriesByStatusParams(msgspec.Struct):
    user_id: int
    status: str


class CategoryBacklogEntry(msgspec.Struct):
    category_id: int
    backlog_entry_id: int
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CategoryBacklogAssociationParams(msgspec.Struct):
    category_id: int
    backlog_entry_id: int


class BacklogEntryResponse(msgspec.Struct):
    """Normalized shape returned by every backlog-entry endpoint - genre
    and platform are always lists (the DB stores them as a single
    comma-separated column), unlike the tRPC prototype this replaces,
    where only one endpoint (getEntries) bothered to transform them and
    the rest returned the raw comma-separated string."""

    id: int
    title: str
    genre: list[str]
    platform: list[str]
    status: str
    owned: bool
    interest: int
    created_at: datetime
    updated_at: datetime
    release_date: date | None = None
    image_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None
    review_stars: int | None = None
    review: str | None = None
    note: str | None = None
    completed_at: datetime | None = None

    @classmethod
    def from_entry(cls, entry: BacklogEntry) -> "BacklogEntryResponse":
        return cls(
            id=entry.backlog_entry_id,
            title=entry.title,
            genre=[g for g in entry.genre.split(", ") if g],
            platform=[p for p in entry.platform.split(", ") if p],
            status=entry.status,
            owned=entry.owned,
            interest=entry.interest,
            created_at=entry.created_at,
            updated_at=entry.updated_at,
            release_date=entry.release_date,
            image_link=entry.image_link,
            main_time=entry.main_time,
            main_plus_extra_time=entry.main_plus_extra_time,
            completion_time=entry.completion_time,
            review_stars=entry.review_stars,
            review=entry.review,
            note=entry.note,
            completed_at=entry.completed_at,
        )


class CreateBacklogEntryRequest(msgspec.Struct):
    title: str
    genre: list[str]
    platform: list[str]
    status: str
    owned: bool
    interest: int
    release_date: date | None = None
    image_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None
    review_stars: float | None = None
    review: str | None = None
    note: str | None = None


class UpdateBacklogEntryRequest(msgspec.Struct):
    """Same UNSET-vs-None distinction as UpdateBacklogEntryParams: an
    omitted field is left unchanged, an explicit null clears a nullable
    field."""

    title: str | msgspec.UnsetType = msgspec.UNSET
    genre: list[str] | msgspec.UnsetType = msgspec.UNSET
    platform: list[str] | msgspec.UnsetType = msgspec.UNSET
    status: str | msgspec.UnsetType = msgspec.UNSET
    owned: bool | msgspec.UnsetType = msgspec.UNSET
    interest: int | msgspec.UnsetType = msgspec.UNSET
    release_date: date | None | msgspec.UnsetType = msgspec.UNSET
    image_link: str | None | msgspec.UnsetType = msgspec.UNSET
    main_time: Decimal | None | msgspec.UnsetType = msgspec.UNSET
    main_plus_extra_time: Decimal | None | msgspec.UnsetType = msgspec.UNSET
    completion_time: Decimal | None | msgspec.UnsetType = msgspec.UNSET
    review_stars: float | None | msgspec.UnsetType = msgspec.UNSET
    review: str | None | msgspec.UnsetType = msgspec.UNSET
    note: str | None | msgspec.UnsetType = msgspec.UNSET

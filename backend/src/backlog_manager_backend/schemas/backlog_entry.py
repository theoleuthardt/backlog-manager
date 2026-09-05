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

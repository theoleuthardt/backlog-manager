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
    backlog_entry_id: int
    title: str | None = None
    genre: str | None = None
    platform: str | None = None
    status: str | None = None
    owned: bool | None = None
    interest: int | None = None
    release_date: date | None = None
    image_link: str | None = None
    main_time: Decimal | None = None
    main_plus_extra_time: Decimal | None = None
    completion_time: Decimal | None = None
    review_stars: int | None = None
    review: str | None = None
    note: str | None = None


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

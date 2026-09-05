from datetime import datetime

import msgspec


class Category(msgspec.Struct):
    category_id: int
    user_id: int
    name: str
    color: str
    description: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CreateCategoryParams(msgspec.Struct):
    user_id: int
    category_name: str
    color: str = "#000000"
    description: str = "No description"


class UpdateCategoryParams(msgspec.Struct):
    category_id: int
    category_name: str | None = None
    color: str | None = None
    description: str | None = None

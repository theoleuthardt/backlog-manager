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
    """UNSET (default) means "field omitted, leave unchanged"; an
    explicit None (only possible for description, the one nullable
    column here) means "clear this field"."""

    category_id: int
    category_name: str | msgspec.UnsetType = msgspec.UNSET
    color: str | msgspec.UnsetType = msgspec.UNSET
    description: str | None | msgspec.UnsetType = msgspec.UNSET


class CategoryResponse(msgspec.Struct):
    id: int
    name: str
    color: str
    description: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    @classmethod
    def from_category(cls, category: Category) -> "CategoryResponse":
        return cls(
            id=category.category_id,
            name=category.name,
            color=category.color,
            description=category.description,
            created_at=category.created_at,
            updated_at=category.updated_at,
        )


class CreateCategoryRequest(msgspec.Struct):
    category_name: str
    color: str = "#000000"
    description: str = "No description"


class UpdateCategoryRequest(msgspec.Struct):
    category_name: str | msgspec.UnsetType = msgspec.UNSET
    color: str | msgspec.UnsetType = msgspec.UNSET
    description: str | None | msgspec.UnsetType = msgspec.UNSET

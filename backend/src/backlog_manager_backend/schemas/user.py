from datetime import datetime

import msgspec


class User(msgspec.Struct):
    id: int
    name: str
    email: str
    created_at: datetime
    updated_at: datetime
    password_hash: str | None = None


class CreateUserParams(msgspec.Struct):
    username: str
    email: str
    password_hash: str
    steam_id: str | None = None


class UpdateUserParams(msgspec.Struct):
    """UNSET (default) means "field omitted, leave unchanged"; an
    explicit None (only possible for nullable columns, i.e. steam_id)
    means "clear this field" - the two aren't interchangeable."""

    user_id: int
    username: str | msgspec.UnsetType = msgspec.UNSET
    email: str | msgspec.UnsetType = msgspec.UNSET
    password_hash: str | msgspec.UnsetType = msgspec.UNSET
    steam_id: str | None | msgspec.UnsetType = msgspec.UNSET

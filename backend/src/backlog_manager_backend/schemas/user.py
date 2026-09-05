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
    user_id: int
    username: str | None = None
    email: str | None = None
    password_hash: str | None = None
    steam_id: str | None = None

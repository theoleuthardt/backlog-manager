from datetime import datetime

import msgspec

from backlog_manager_backend.schemas.user import User


class RegisterParams(msgspec.Struct):
    username: str
    email: str
    password: str
    steam_id: str | None = None


class LoginParams(msgspec.Struct):
    email: str
    password: str


class TokenResponse(msgspec.Struct):
    access_token: str
    token_type: str = "bearer"


class PublicUser(msgspec.Struct):
    """User, minus password_hash - never expose that over the API."""

    id: int
    name: str
    email: str
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_user(cls, user: User) -> "PublicUser":
        return cls(
            id=user.id,
            name=user.name,
            email=user.email,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )

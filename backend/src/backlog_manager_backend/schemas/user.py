from datetime import datetime

import msgspec


class User(msgspec.Struct):
    id: int
    name: str
    email: str
    created_at: datetime
    updated_at: datetime
    password_hash: str | None = None
    is_admin: bool = False


class CreateUserParams(msgspec.Struct):
    username: str
    email: str
    password_hash: str
    steam_id: str | None = None
    is_admin: bool = False


class UpdateUserParams(msgspec.Struct):
    """UNSET (default) means "field omitted, leave unchanged"; an
    explicit None (only possible for nullable columns, i.e. steam_id)
    means "clear this field" - the two aren't interchangeable."""

    user_id: int
    username: str | msgspec.UnsetType = msgspec.UNSET
    email: str | msgspec.UnsetType = msgspec.UNSET
    password_hash: str | msgspec.UnsetType = msgspec.UNSET
    steam_id: str | None | msgspec.UnsetType = msgspec.UNSET
    is_admin: bool | msgspec.UnsetType = msgspec.UNSET


class PublicUser(msgspec.Struct):
    """User, minus password_hash - never expose that over the API."""

    id: int
    name: str
    email: str
    is_admin: bool
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_user(cls, user: User) -> "PublicUser":
        return cls(
            id=user.id,
            name=user.name,
            email=user.email,
            is_admin=user.is_admin,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )


class PublicUsername(msgspec.Struct):
    """The only fields safe to return from an unauthenticated username
    lookup - no email, is_admin, or timestamps. PublicUser is for
    authenticated self/admin views only; it must never back a public
    endpoint."""

    id: int
    name: str

    @classmethod
    def from_user(cls, user: User) -> "PublicUsername":
        return cls(id=user.id, name=user.name)


class UpdateOwnUserRequest(msgspec.Struct):
    """Same UNSET-vs-None semantics as UpdateUserParams. `password` is
    the plaintext new password (hashed server-side before it ever
    reaches UpdateUserParams.password_hash) - unlike the tRPC prototype
    this replaces, which wrote whatever the client sent straight into
    the PasswordHash column unhashed. Deliberately has no `is_admin`
    field - a user can never change their own admin status."""

    username: str | msgspec.UnsetType = msgspec.UNSET
    email: str | msgspec.UnsetType = msgspec.UNSET
    password: str | msgspec.UnsetType = msgspec.UNSET
    steam_id: str | None | msgspec.UnsetType = msgspec.UNSET


class UpdateUserAdminRequest(msgspec.Struct):
    """Same as UpdateOwnUserRequest, plus is_admin - only admins can
    promote/demote other users, via this request type alone."""

    username: str | msgspec.UnsetType = msgspec.UNSET
    email: str | msgspec.UnsetType = msgspec.UNSET
    password: str | msgspec.UnsetType = msgspec.UNSET
    steam_id: str | None | msgspec.UnsetType = msgspec.UNSET
    is_admin: bool | msgspec.UnsetType = msgspec.UNSET


class CreateUserRequest(msgspec.Struct):
    """Admin-only user creation - there is no public self-registration
    endpoint. `is_admin` lets an admin create additional admins."""

    username: str
    email: str
    password: str
    steam_id: str | None = None
    is_admin: bool = False

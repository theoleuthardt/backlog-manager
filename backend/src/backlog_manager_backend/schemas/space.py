from datetime import datetime

import msgspec


class SpaceMemberRecord(msgspec.Struct):
    space_id: int
    user_id: int
    username: str
    status: str
    avatar_updated_at: datetime | None = None


class InviteToSpaceRequest(msgspec.Struct):
    username: str


class SpaceMemberResponse(msgspec.Struct):
    """`user_id` and `avatar_updated_at` let the client fetch the member's
    picture (`GET /api/user/{user_id}/avatar`) and tell when it changed."""

    username: str
    status: str
    is_me: bool
    user_id: int = 0
    avatar_updated_at: datetime | None = None


class SpaceResponse(msgspec.Struct):
    """`space_id`/`my_status` are None when the caller belongs to no
    space and has no pending invitation."""

    space_id: int | None
    my_status: str | None
    members: list[SpaceMemberResponse]

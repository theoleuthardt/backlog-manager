import msgspec


class SpaceMemberRecord(msgspec.Struct):
    space_id: int
    user_id: int
    username: str
    status: str


class InviteToSpaceRequest(msgspec.Struct):
    username: str


class SpaceMemberResponse(msgspec.Struct):
    username: str
    status: str
    is_me: bool


class SpaceResponse(msgspec.Struct):
    """`space_id`/`my_status` are None when the caller belongs to no
    space and has no pending invitation."""

    space_id: int | None
    my_status: str | None
    members: list[SpaceMemberResponse]

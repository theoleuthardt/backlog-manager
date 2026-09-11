from datetime import datetime

import msgspec


class CustomStatus(msgspec.Struct):
    status_id: int
    user_id: int
    name: str
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CreateCustomStatusParams(msgspec.Struct):
    user_id: int
    name: str


class UpdateCustomStatusParams(msgspec.Struct):
    status_id: int
    name: str


class CustomStatusResponse(msgspec.Struct):
    id: int
    name: str

    @classmethod
    def from_status(cls, status: CustomStatus) -> "CustomStatusResponse":
        return cls(id=status.status_id, name=status.name)


class CreateCustomStatusRequest(msgspec.Struct):
    name: str


class UpdateCustomStatusRequest(msgspec.Struct):
    name: str
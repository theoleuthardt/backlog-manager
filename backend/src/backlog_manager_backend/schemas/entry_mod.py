import msgspec

from backlog_manager_backend.schemas.types import WebUrl

MAX_MOD_NAME_LENGTH = 120
MAX_MODS_PER_ENTRY = 100


class EntryMod(msgspec.Struct):
    mod_id: int
    backlog_entry_id: int
    name: str
    url: str | None = None


class EntryModResponse(msgspec.Struct):
    id: int
    name: str
    url: str | None = None

    @classmethod
    def from_mod(cls, mod: EntryMod) -> "EntryModResponse":
        return cls(id=mod.mod_id, name=mod.name, url=mod.url)


class CreateEntryModRequest(msgspec.Struct):
    name: str
    url: WebUrl | None = None


class UpdateEntryModRequest(msgspec.Struct):
    """An omitted field stays as it is, an explicit null link removes it."""

    name: str | msgspec.UnsetType = msgspec.UNSET
    url: WebUrl | None | msgspec.UnsetType = msgspec.UNSET

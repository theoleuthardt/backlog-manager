import re

import msgspec

_UNKNOWN_TAG = "Unknown"

_TYPO_ALIASES = {
    "onwed": "Owned",
}

_CONSOLE_ALIASES = {
    "3ds": "3DS",
    "ds": "DS",
    "gc": "GC",
    "pc": "PC",
    "ps1": "PS1",
    "ps2": "PS2",
    "ps4": "PS4",
    "switch": "Switch",
    "wii": "Wii",
    "wiiu": "WiiU",
}

_STOREFRONT_ALIASES = {
    "ea": "EA App",
    "epic": "Epic Games",
    "gog": "GOG",
}

_EMU_QUALIFIER_RE = re.compile(r"^(?P<system>.+?)\s+Emu$", re.IGNORECASE)
_PAREN_RE = re.compile(r"^(?P<base>.+?)\s*\((?P<qualifier>[^)]+)\)\s*$")


class PlatformMapping(msgspec.Struct):
    platform: list[str]
    owned: bool
    note: str | None = None


def _canonicalize(token: str) -> str:
    token = token.strip()
    alias = _TYPO_ALIASES.get(token.lower())
    if alias is not None:
        return alias
    console = _CONSOLE_ALIASES.get(token.lower())
    if console is not None:
        return console
    return token


def normalize_platform(raw: str) -> PlatformMapping:
    """Turns one MYY-sheet `Platform` cell into (platform tags, owned,
    optional note): `Owned`/`Friend` describe PC storefront access
    rather than hardware, console names in
    parens after `Owned` are ambiguous (e.g. emulator vs. digital
    purchase) so they get flagged `Unknown` for manual review instead of
    guessed at, and any other unrecognized qualifier is kept as a second
    platform tag (never silently dropped) with the same `Unknown` flag."""
    value = raw.strip()

    paren_match = _PAREN_RE.match(value)
    if paren_match:
        base = _canonicalize(paren_match.group("base"))
        qualifier = paren_match.group("qualifier").strip()
        return _normalize_with_qualifier(base, qualifier)

    emu_match = _EMU_QUALIFIER_RE.match(value)
    if emu_match:
        system = _canonicalize(emu_match.group("system"))
        return PlatformMapping(platform=["PC", f"{system} (Emulator)"], owned=True)

    base = _canonicalize(value)
    if base == "Owned":
        return PlatformMapping(platform=["PC"], owned=True)
    if base == "Friend":
        return PlatformMapping(platform=["PC", "Friend"], owned=True)
    return PlatformMapping(platform=[base], owned=True)


def _normalize_with_qualifier(base: str, qualifier: str) -> PlatformMapping:
    if base == "Owned":
        storefront = _STOREFRONT_ALIASES.get(qualifier.lower())
        if storefront is not None:
            return PlatformMapping(platform=["PC", storefront], owned=True)
        return PlatformMapping(platform=["PC", _UNKNOWN_TAG], owned=True, note=f"({qualifier})")

    if qualifier.lower() == "dlc":
        return PlatformMapping(platform=[base], owned=True, note="(DLC)")

    emu_match = _EMU_QUALIFIER_RE.match(qualifier)
    if emu_match:
        system = _canonicalize(emu_match.group("system"))
        return PlatformMapping(platform=[base, f"{system} (Emulator)"], owned=True)

    return PlatformMapping(platform=[base, _UNKNOWN_TAG], owned=True, note=f"({qualifier})")

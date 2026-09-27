from backlog_manager_backend.csv.platform_mapping import normalize_platform


def test_owned_alone_maps_to_pc_steam() -> None:
    result = normalize_platform("Owned")

    assert result.platform == ["PC"]
    assert result.owned is True
    assert result.note is None


def test_owned_with_known_storefront_maps_to_pc_and_storefront() -> None:
    assert normalize_platform("Owned (EA)").platform == ["PC", "EA App"]
    assert normalize_platform("Owned (Epic)").platform == ["PC", "Epic Games"]
    assert normalize_platform("Owned (GOG)").platform == ["PC", "GOG"]


def test_owned_with_unrecognized_qualifier_is_flagged_unknown() -> None:
    result = normalize_platform("Owned (Switch)")

    assert result.platform == ["PC", "Unknown"]
    assert result.owned is True


def test_friend_keeps_owned_true_but_tags_friend() -> None:
    result = normalize_platform("Friend")

    assert result.platform == ["PC", "Friend"]
    assert result.owned is True


def test_console_with_emulator_qualifier() -> None:
    result = normalize_platform("3DS (GBA Emu)")

    assert result.platform == ["3DS", "GBA (Emulator)"]
    assert result.owned is True


def test_switch_with_snes_emulator_qualifier() -> None:
    result = normalize_platform("Switch (SNES Emu)")

    assert result.platform == ["Switch", "SNES (Emulator)"]


def test_console_with_dlc_qualifier_moves_hint_to_note() -> None:
    result = normalize_platform("PS4 (DLC)")

    assert result.platform == ["PS4"]
    assert result.owned is True
    assert result.note == "(DLC)"


def test_console_alone() -> None:
    for raw, expected in [
        ("3DS", "3DS"),
        ("PS4", "PS4"),
        ("DS", "DS"),
        ("Wii", "Wii"),
        ("WiiU", "WiiU"),
    ]:
        result = normalize_platform(raw)
        assert result.platform == [expected]
        assert result.owned is True


def test_standalone_emulator_without_console_prefix() -> None:
    for raw, system in [
        ("GBC Emu", "GBC"),
        ("GC Emu", "GC"),
        ("PS1 Emu", "PS1"),
        ("PS2 Emu", "PS2"),
    ]:
        result = normalize_platform(raw)
        assert result.platform == ["PC", f"{system} (Emulator)"]
        assert result.owned is True


def test_unrecognized_value_is_flagged_unknown_without_dropping_info() -> None:
    result = normalize_platform("Vita (Hacked)")

    assert result.platform == ["Vita", "Unknown"]
    assert result.owned is True


def test_typos_and_whitespace_are_normalized() -> None:
    assert normalize_platform("Onwed").platform == ["PC"]
    assert normalize_platform("SWITCH").platform == ["Switch"]
    assert normalize_platform("Switch ").platform == ["Switch"]
    assert normalize_platform(" 3DS  (GBA Emu) ").platform == ["3DS", "GBA (Emulator)"]

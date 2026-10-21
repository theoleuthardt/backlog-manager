from backlog_manager_backend.sanitize import sanitize_text, sanitize_tree

RLO = "\N{RIGHT-TO-LEFT OVERRIDE}"
PDF = "\N{POP DIRECTIONAL FORMATTING}"
ZWSP = "\N{ZERO WIDTH SPACE}"
ZWJ = "\N{ZERO WIDTH JOINER}"
WJ = "\N{WORD JOINER}"
BOM = "\N{ZERO WIDTH NO-BREAK SPACE}"
LRM = "\N{LEFT-TO-RIGHT MARK}"
RLM = "\N{RIGHT-TO-LEFT MARK}"
LRI = "\N{LEFT-TO-RIGHT ISOLATE}"
PDI = "\N{POP DIRECTIONAL ISOLATE}"


def test_removes_bidi_overrides_and_zero_width_characters() -> None:
    assert sanitize_text(f"{RLO}evil{PDF}{ZWSP}{WJ}{BOM}{LRM}{RLM}{LRI}x{PDI}") == "evilx"


def test_trims_whitespace_at_the_edges() -> None:
    assert sanitize_text("  Celeste \n") == "Celeste"


def test_keeps_punctuation_that_looks_like_code() -> None:
    title = 'Assassin\'s Creed; {Deluxe} "<GOTY>" -- 100% /* */'
    assert sanitize_text(title) == title


def test_keeps_line_breaks_and_tabs_inside_the_text() -> None:
    assert sanitize_text("line one\n\tline two\r\nthree") == "line one\n\tline two\r\nthree"


def test_removes_other_control_characters() -> None:
    controls = [chr(code) for code in (0x00, 0x07, 0x1B, 0x7F, 0x85, 0x9F)]
    assert sanitize_text("a" + "".join(f"{c}{n}" for c, n in zip(controls, "bcdefg"))) == "abcdefg"


def test_normalizes_to_composed_unicode() -> None:
    decomposed = "Poke\N{COMBINING ACUTE ACCENT}mon"
    assert sanitize_text(decomposed) == "Pok\N{LATIN SMALL LETTER E WITH ACUTE}mon"


def test_keeps_emoji_joined_with_zero_width_joiner() -> None:
    family = f"\N{MAN}{ZWJ}\N{WOMAN}{ZWJ}\N{GIRL}"
    assert sanitize_text(family) == family


def test_sanitizes_every_string_value_in_a_tree_but_not_passwords() -> None:
    tree = {
        "title": f" Celeste{ZWSP} ",
        "password": f"  {ZWSP}exactly as typed ",
        "genre": [" Platformer ", f"{RLO}Indie"],
        "nested": {"name": f"{LRI}x{PDI}", "password": " inner "},
        "interest": 8,
        "owned": True,
        "note": None,
        " key ": "value",
    }

    assert sanitize_tree(tree) == {
        "title": "Celeste",
        "password": f"  {ZWSP}exactly as typed ",
        "genre": ["Platformer", "Indie"],
        "nested": {"name": "x", "password": " inner "},
        "interest": 8,
        "owned": True,
        "note": None,
        " key ": "value",
    }


def test_sanitizes_a_bare_string_or_list_body() -> None:
    assert sanitize_tree(f" a{ZWSP} ") == "a"
    assert sanitize_tree([" a ", 1]) == ["a", 1]

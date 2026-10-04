from backlog_manager_backend.csv import parse_csv


def test_extract_csv_headers_reads_first_row_by_column_letter() -> None:
    headers = parse_csv.extract_csv_headers(
        "Game,Genre,Platform,Status\nCeleste,Platformer,PC,Not Started"
    )

    assert headers == {"A": "Game", "B": "Genre", "C": "Platform", "D": "Status"}


def test_extract_csv_headers_returns_empty_dict_for_empty_content() -> None:
    assert parse_csv.extract_csv_headers("") == {}


def test_parse_csv_content_skips_the_header_row() -> None:
    records = parse_csv.parse_csv_content(
        "Game,Genre,Platform,Status\nCeleste,Platformer,PC,Not Started\nHades,Roguelike,PC,Completed"
    )

    assert records == [
        {"A": "Celeste", "B": "Platformer", "C": "PC", "D": "Not Started"},
        {"A": "Hades", "B": "Roguelike", "C": "PC", "D": "Completed"},
    ]


def test_parse_csv_content_skips_empty_lines() -> None:
    records = parse_csv.parse_csv_content(
        "Game,Genre,Platform,Status\nCeleste,Platformer,PC,Not Started\n\n\nHades,Roguelike,PC,Completed"
    )

    assert len(records) == 2

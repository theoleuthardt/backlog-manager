import msgspec


class CsvHeadersRequest(msgspec.Struct):
    content: str


class MatchCsvRequest(msgspec.Struct):
    content: str
    title_column: str
    genre_column: str
    platform_column: str
    status_column: str
    playtime_column: str | None = None
    rating_column: str | None = None
    completed_at_column: str | None = None
    note_columns: list[str] = []
    review_columns: list[str] = []


class CsvHeadersResponse(msgspec.Struct):
    headers: dict[str, str]

import msgspec


class ParseCsvRequest(msgspec.Struct):
    content: str


class ImportCsvRequest(msgspec.Struct):
    content: str
    title_column: str
    genre_column: str
    platform_column: str
    status_column: str
    session_id: str | None = None


class ImportProgressResponse(msgspec.Struct):
    processed: int

from litestar import Router, get, post
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotFoundException
from litestar.params import FromPath
from litestar.status_codes import HTTP_200_OK, HTTP_204_NO_CONTENT, HTTP_409_CONFLICT
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import get_current_user
from backlog_manager_backend.csv.parse_csv import (
    ColumnConfig,
    CSVRecord,
    ImportResult,
    get_import_progress,
    get_import_session_owner,
    import_backlog_entries_from_csv,
    parse_csv_content,
    set_cancel_flag,
)
from backlog_manager_backend.errors import ConflictError
from backlog_manager_backend.schemas.csv import (
    ImportCsvRequest,
    ImportProgressResponse,
    ParseCsvRequest,
)
from backlog_manager_backend.schemas.user import User

_IMPORT_SESSION_NOT_FOUND = "Import session not found"


def _require_owned_session(session_id: str, current_user: User) -> None:
    """A session_id the server has never seen (unregistered - e.g. a typo,
    or the import used no session_id at all) is let through: it carries
    no information either way. One registered to a *different* user is
    rejected as 404, not 403, so a caller can't distinguish "not yours"
    from "doesn't exist"."""
    owner = get_import_session_owner(session_id)
    if owner is not None and owner != current_user.id:
        raise NotFoundException(_IMPORT_SESSION_NOT_FOUND)


@post("/api/csv/parse", status_code=HTTP_200_OK)
async def parse_csv(data: ParseCsvRequest, current_user: NamedDependency[User]) -> list[CSVRecord]:
    return parse_csv_content(data.content)


@post("/api/csv/import", status_code=HTTP_200_OK)
async def import_csv(
    data: ImportCsvRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> ImportResult:
    records = parse_csv_content(data.content)
    config = ColumnConfig(
        title_column=data.title_column,
        genre_column=data.genre_column,
        platform_column=data.platform_column,
        status_column=data.status_column,
    )
    try:
        return await import_backlog_entries_from_csv(
            db_session, current_user.id, records, config, data.session_id
        )
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error


@get("/api/csv/import/{session_id:str}/progress")
async def get_csv_import_progress(
    session_id: FromPath[str], current_user: NamedDependency[User]
) -> ImportProgressResponse:
    _require_owned_session(session_id, current_user)
    return ImportProgressResponse(processed=get_import_progress(session_id))


@post("/api/csv/import/{session_id:str}/cancel", status_code=HTTP_204_NO_CONTENT)
async def cancel_csv_import(session_id: FromPath[str], current_user: NamedDependency[User]) -> None:
    _require_owned_session(session_id, current_user)
    set_cancel_flag(session_id, True)


csv_router = Router(
    path="",
    route_handlers=[parse_csv, import_csv, get_csv_import_progress, cancel_csv_import],
    dependencies={"current_user": Provide(get_current_user)},
)

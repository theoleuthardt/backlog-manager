"""Backup list/create/download/restore/delete HTTP handlers.

Same router-level-dependency gotcha as routes/auth.py's two_factor_router:
every handler declares `current_user: NamedDependency[User]` itself, or
get_current_user never runs for it."""

import msgspec
from litestar import Response, Router, delete, get, post
from litestar.datastructures import CacheControlHeader
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotFoundException
from litestar.params import FromPath
from litestar.status_codes import HTTP_200_OK, HTTP_201_CREATED, HTTP_204_NO_CONTENT
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.errors import NotFoundError, ValidationError
from backlog_manager_backend.schemas.backup import BackupSummary, RestoreResult
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import backup_service

_NO_STORE = CacheControlHeader(no_store=True)
_BACKUP_NOT_FOUND = "Backup not found"


@get("/api/backups")
async def list_backups(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> list[BackupSummary]:
    return await backup_service.list_backups(db_session, current_user.id)


@post("/api/backups", status_code=HTTP_201_CREATED)
async def create_backup(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> BackupSummary:
    """Takes a manual snapshot of the caller's personal backlog."""
    return await backup_service.create_manual_backup(db_session, current_user.id)


@get("/api/backups/{backup_id:int}/download", status_code=HTTP_200_OK)
async def download_backup(
    backup_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> Response:
    try:
        payload = await backup_service.export_backup(db_session, current_user.id, backup_id)
    except NotFoundError as error:
        raise NotFoundException(_BACKUP_NOT_FOUND) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    return Response(
        msgspec.json.encode(payload),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="backlog-backup-{backup_id}.json"'},
    )


@post("/api/backups/{backup_id:int}/restore", status_code=HTTP_200_OK)
async def restore_backup(
    backup_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> RestoreResult:
    """Replaces the caller's personal backlog with the snapshot. A
    "pre-restore" safety snapshot of the current state is taken first
    (`safety_backup_id`), so a restore can itself be reverted."""
    try:
        return await backup_service.restore_backup(db_session, current_user.id, backup_id)
    except NotFoundError as error:
        raise NotFoundException(_BACKUP_NOT_FOUND) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error


@delete("/api/backups/{backup_id:int}", status_code=HTTP_204_NO_CONTENT)
async def delete_backup(
    backup_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    try:
        await backup_service.delete_backup(db_session, current_user.id, backup_id)
    except NotFoundError as error:
        raise NotFoundException(_BACKUP_NOT_FOUND) from error


backup_router = Router(
    path="",
    route_handlers=[list_backups, create_backup, download_backup, restore_backup, delete_backup],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
    cache_control=_NO_STORE,
)

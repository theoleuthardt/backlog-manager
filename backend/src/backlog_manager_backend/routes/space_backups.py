"""Backups and the JSON export of the shared space. Either active member
can use every route; a restore needs both (see
services/space_backup_service.py). A caller without an active membership
gets a 404, like for any other space route."""

import msgspec
from litestar import Response, Router, delete, get, post, put
from litestar.datastructures import CacheControlHeader
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotFoundException
from litestar.params import FromPath
from litestar.status_codes import (
    HTTP_200_OK,
    HTTP_201_CREATED,
    HTTP_204_NO_CONTENT,
    HTTP_409_CONFLICT,
)
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError
from backlog_manager_backend.schemas.backup import (
    BackupSummary,
    RenameBackupRequest,
    RestoreResult,
)
from backlog_manager_backend.schemas.space_backup import (
    SpaceBackupList,
    SpaceBackupSummary,
    SpaceRestoreResponse,
)
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import space_backup_service

_NO_STORE = CacheControlHeader(no_store=True)


class _SpaceBackupConflictException(ClientException):
    """Documents the 409 a restore that cannot run raises."""

    status_code = HTTP_409_CONFLICT


def _not_found(error: NotFoundError) -> NotFoundException:
    return NotFoundException(
        "Space not found" if "Space with" in str(error) else "Backup not found"
    )


@get("/api/space/backups", raises=[NotFoundException])
async def list_space_backups(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> SpaceBackupList:
    """The space's backups, newest first, and the restore waiting for
    approval (`restore_request`), if any."""
    try:
        return await space_backup_service.list_backups(db_session, current_user)
    except NotFoundError as error:
        raise _not_found(error) from error


@post("/api/space/backups", status_code=HTTP_201_CREATED, raises=[NotFoundException])
async def create_space_backup(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> SpaceBackupSummary:
    """Takes a manual snapshot of the shared space."""
    try:
        return await space_backup_service.create_manual_backup(db_session, current_user)
    except NotFoundError as error:
        raise _not_found(error) from error


@get(
    "/api/space/backups/{backup_id:int}/download",
    status_code=HTTP_200_OK,
    raises=[NotFoundException, ClientException],
)
async def download_space_backup(
    backup_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> Response:
    """The snapshot as a JSON file with the caller's own per-member fields
    only."""
    try:
        payload = await space_backup_service.export_backup(db_session, current_user, backup_id)
    except NotFoundError as error:
        raise _not_found(error) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    return Response(
        msgspec.json.encode(payload),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="space-backup-{backup_id}.json"'},
    )


@get("/api/space/export", status_code=HTTP_200_OK, raises=[NotFoundException])
async def export_space(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> Response:
    """The current content of the space as a JSON file (same format as a
    backup download), with the caller's own per-member fields only."""
    try:
        payload = await space_backup_service.export_space(db_session, current_user)
    except NotFoundError as error:
        raise _not_found(error) from error
    return Response(
        msgspec.json.encode(payload),
        media_type="application/json",
        headers={"Content-Disposition": 'attachment; filename="space-backlog.json"'},
    )


@put(
    "/api/space/backups/{backup_id:int}",
    status_code=HTTP_200_OK,
    raises=[NotFoundException, ClientException],
)
async def rename_space_backup(
    backup_id: FromPath[int],
    data: RenameBackupRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> BackupSummary:
    """Sets or clears the backup's label; the snapshot content is untouched."""
    try:
        return await space_backup_service.rename_backup(
            db_session, current_user, backup_id, data.name
        )
    except NotFoundError as error:
        raise _not_found(error) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error


@delete(
    "/api/space/backups/{backup_id:int}",
    status_code=HTTP_204_NO_CONTENT,
    raises=[NotFoundException],
)
async def delete_space_backup(
    backup_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    try:
        await space_backup_service.delete_backup(db_session, current_user, backup_id)
    except NotFoundError as error:
        raise _not_found(error) from error


@post(
    "/api/space/backups/{backup_id:int}/restore",
    status_code=HTTP_200_OK,
    raises=[NotFoundException, ClientException, _SpaceBackupConflictException],
)
async def restore_space_backup(
    backup_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> SpaceRestoreResponse:
    """Asks the other member to approve restoring the snapshot
    (`restored` false, the open `request`); only when the caller is the
    space's only active member does it run at once. A 409 means a restore
    is already waiting."""
    try:
        return await space_backup_service.request_restore(db_session, current_user, backup_id)
    except NotFoundError as error:
        raise _not_found(error) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    except ConflictError as error:
        raise _SpaceBackupConflictException(str(error)) from error


@post(
    "/api/space/restore-request/approve",
    status_code=HTTP_200_OK,
    raises=[NotFoundException, ClientException, _SpaceBackupConflictException],
)
async def approve_space_restore(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> RestoreResult:
    """The member who did not ask for the restore approves it and it runs.
    A "pre-restore" snapshot of the current state is taken first
    (`safety_backup_id`). The one who asked gets a 409."""
    try:
        return await space_backup_service.approve_restore(db_session, current_user)
    except NotFoundError as error:
        raise NotFoundException(
            "Space not found" if "Space with" in str(error) else "No restore waiting for approval"
        ) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    except ConflictError as error:
        raise _SpaceBackupConflictException(str(error)) from error


@delete("/api/space/restore-request", status_code=HTTP_204_NO_CONTENT, raises=[NotFoundException])
async def withdraw_space_restore_request(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> None:
    """Ends the open restore request: the member who asked takes it back,
    the other one declines it."""
    try:
        await space_backup_service.withdraw_restore_request(db_session, current_user)
    except NotFoundError as error:
        raise _not_found(error) from error


space_backup_router = Router(
    path="",
    route_handlers=[
        list_space_backups,
        create_space_backup,
        download_space_backup,
        export_space,
        rename_space_backup,
        delete_space_backup,
        restore_space_backup,
        approve_space_restore,
        withdraw_space_restore_request,
    ],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
    cache_control=_NO_STORE,
)

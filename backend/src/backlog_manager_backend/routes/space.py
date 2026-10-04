"""HTTP handlers for the shared space: the two-user backlog a user is
invited into by username. Entries, categories and statuses of a space
are served by the backlog routes through their `space_id` query
parameter (see routes/backlog.py)."""

from litestar import Router, delete, get, post
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotFoundException, ValidationException
from litestar.status_codes import (
    HTTP_200_OK,
    HTTP_201_CREATED,
    HTTP_204_NO_CONTENT,
    HTTP_409_CONFLICT,
)
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError
from backlog_manager_backend.repositories import space_repo
from backlog_manager_backend.schemas.space import (
    InviteToSpaceRequest,
    SpaceMemberResponse,
    SpaceResponse,
)
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import space_service


class _SpaceConflictException(ClientException):
    """Documents the 409 an invitation the space can't take raises."""

    status_code = HTTP_409_CONFLICT


async def _space_state(session: AsyncSession, user: User) -> SpaceResponse:
    membership = await space_repo.get_membership(session, user.id)
    if membership is None:
        return SpaceResponse(space_id=None, my_status=None, members=[])
    members = await space_repo.get_members(session, membership.space_id)
    return SpaceResponse(
        space_id=membership.space_id,
        my_status=membership.status,
        members=[
            SpaceMemberResponse(
                username=member.username, status=member.status, is_me=member.user_id == user.id
            )
            for member in members
        ],
    )


@get("/api/space")
async def get_space(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> SpaceResponse:
    return await _space_state(db_session, current_user)


@post(
    "/api/space/invitations",
    status_code=HTTP_201_CREATED,
    raises=[NotFoundException, ValidationException, _SpaceConflictException],
)
async def invite_to_space(
    data: InviteToSpaceRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    try:
        await space_service.invite_user(db_session, current_user, data.username)
    except NotFoundError as error:
        raise NotFoundException("No user with that username") from error
    except ValidationError as error:
        raise ValidationException(str(error)) from error
    except ConflictError as error:
        raise _SpaceConflictException(str(error)) from error


@post("/api/space/invitations/accept", status_code=HTTP_200_OK, raises=[NotFoundException])
async def accept_space_invitation(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> SpaceResponse:
    try:
        await space_service.accept_invitation(db_session, current_user)
    except NotFoundError as error:
        raise NotFoundException("No pending invitation") from error
    return await _space_state(db_session, current_user)


@delete("/api/space/membership", status_code=HTTP_204_NO_CONTENT)
async def leave_space(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    """Leaves the caller's space, or declines their pending invitation."""
    await space_service.leave_space(db_session, current_user)


space_router = Router(
    path="",
    route_handlers=[get_space, invite_to_space, accept_space_invitation, leave_space],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
)

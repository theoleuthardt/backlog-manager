from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError
from backlog_manager_backend.repositories import space_repo, user_repo
from backlog_manager_backend.schemas.space import SpaceMemberRecord
from backlog_manager_backend.schemas.user import User

MAX_SPACE_MEMBERS = 2


async def invite_user(session: AsyncSession, inviter: User, username: str) -> None:
    """Invites the user registered under `username` into the inviter's
    space, creating that space on the first invitation. A space holds at
    most MAX_SPACE_MEMBERS users (pending invitations count), and a user
    can belong to or be invited into only one space at a time."""
    invitee = await user_repo.get_user_by_username(session, username.strip())
    if invitee is None:
        raise NotFoundError("User", username)
    if invitee.id == inviter.id:
        raise ValidationError("You cannot invite yourself")
    if await space_repo.get_membership(session, invitee.id) is not None:
        raise ConflictError("That user already belongs to or is invited to a space")

    membership = await space_repo.get_membership(session, inviter.id)
    if membership is None:
        space_id = await space_repo.create_space(session, inviter.id)
    elif membership.status != "active":
        raise ConflictError("Accept your invitation before inviting someone else")
    else:
        space_id = membership.space_id

    await space_repo.lock_space(session, space_id)
    if len(await space_repo.get_members(session, space_id)) >= MAX_SPACE_MEMBERS:
        raise ConflictError("This space is already full")
    await space_repo.add_invited_member(session, space_id, invitee.id)


async def accept_invitation(session: AsyncSession, user: User) -> SpaceMemberRecord:
    membership = await space_repo.get_membership(session, user.id)
    if membership is None or membership.status != "invited":
        raise NotFoundError("SpaceInvitation", user.id)
    await space_repo.activate_member(session, membership.space_id, user.id)
    return membership


async def leave_space(session: AsyncSession, user: User) -> None:
    """Covers declining a pending invitation as well as leaving a space
    the user is an active member of."""
    membership = await space_repo.get_membership(session, user.id)
    if membership is None:
        return
    await space_repo.remove_member(session, membership.space_id, user.id)

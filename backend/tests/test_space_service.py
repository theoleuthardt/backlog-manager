import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError
from backlog_manager_backend.repositories import space_repo, user_repo
from backlog_manager_backend.schemas.user import CreateUserParams
from backlog_manager_backend.services import space_service


async def _make_user(session: AsyncSession, name: str) -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username=name, email=f"{name}@example.com", password_hash="h"),
    )


async def test_concurrent_invitation_of_the_same_user_reports_the_specific_conflict(
    session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Simulates the race: the invitee's membership check passes, then
    another space's invitation lands before ours is written, so only the
    UserID unique constraint catches it."""
    first = await _make_user(session, "racefirst")
    second = await _make_user(session, "racesecond")
    invitee = await _make_user(session, "raceinvitee")
    first_space = await space_repo.create_space(session, first.id)
    await space_repo.create_space(session, second.id)
    await space_repo.add_invited_member(session, first_space, invitee.id)

    original = space_repo.get_membership

    async def membership_blind_to_invitee(session: AsyncSession, user_id: int) -> object:
        if user_id == invitee.id:
            return None
        return await original(session, user_id)

    monkeypatch.setattr(space_repo, "get_membership", membership_blind_to_invitee)

    with pytest.raises(ConflictError, match="already belongs to or is invited"):
        await space_service.invite_user(session, second, "raceinvitee")

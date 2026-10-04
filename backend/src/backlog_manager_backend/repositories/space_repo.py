from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import handle_database_error
from backlog_manager_backend.models.backlog_entry import BacklogEntry as BacklogEntryModel
from backlog_manager_backend.models.category import Category as CategoryModel
from backlog_manager_backend.models.custom_status import CustomStatus as CustomStatusModel
from backlog_manager_backend.models.space import Space as SpaceModel
from backlog_manager_backend.models.space import SpaceMember as SpaceMemberModel
from backlog_manager_backend.models.space_entry_member_data import SpaceEntryMemberData
from backlog_manager_backend.models.user import User as UserModel
from backlog_manager_backend.schemas.space import SpaceMemberRecord
from backlog_manager_backend.utils import now_truncated_to_minute


async def get_members(session: AsyncSession, space_id: int) -> list[SpaceMemberRecord]:
    result = await session.execute(
        select(SpaceMemberModel, UserModel.username)
        .join(UserModel, UserModel.id == SpaceMemberModel.user_id)
        .where(SpaceMemberModel.space_id == space_id)
        .order_by(SpaceMemberModel.created_at, SpaceMemberModel.user_id)
    )
    return [
        SpaceMemberRecord(
            space_id=member.space_id,
            user_id=member.user_id,
            username=username,
            status=member.status,
        )
        for member, username in result.all()
    ]


async def get_membership(session: AsyncSession, user_id: int) -> SpaceMemberRecord | None:
    result = await session.execute(
        select(SpaceMemberModel, UserModel.username)
        .join(UserModel, UserModel.id == SpaceMemberModel.user_id)
        .where(SpaceMemberModel.user_id == user_id)
    )
    row = result.first()
    if row is None:
        return None
    member, username = row
    return SpaceMemberRecord(
        space_id=member.space_id, user_id=member.user_id, username=username, status=member.status
    )


async def create_space(session: AsyncSession, owner_id: int) -> int:
    """Creates a space with `owner_id` as its first, already active member."""
    space = SpaceModel()
    session.add(space)
    await session.flush()
    session.add(SpaceMemberModel(space_id=space.id, user_id=owner_id, status="active"))
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "create_space")
    return space.id


async def lock_space(session: AsyncSession, space_id: int) -> None:
    """Row-locks the space until the transaction ends, serializing
    concurrent invitations so the member limit can't be raced past."""
    await session.execute(
        select(SpaceModel.id).where(SpaceModel.id == space_id).with_for_update()
    )


async def add_invited_member(session: AsyncSession, space_id: int, user_id: int) -> None:
    session.add(SpaceMemberModel(space_id=space_id, user_id=user_id, status="invited"))
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "add_invited_member")


async def activate_member(session: AsyncSession, space_id: int, user_id: int) -> None:
    member = await session.get(SpaceMemberModel, (space_id, user_id))
    if member is None:
        return
    member.status = "active"
    member.updated_at = now_truncated_to_minute()
    await session.commit()


async def remove_member(session: AsyncSession, space_id: int, user_id: int) -> None:
    """Removes one member and deletes the space (with its entries,
    categories and statuses, via ON DELETE CASCADE) once no active
    member is left - a space holding only a pending invitation is
    meaningless. The leaver's per-member data (playtime, rating, review)
    on the space's entries is deleted with them, so the remaining member
    no longer sees their playtime. The entries, categories and statuses
    the leaver created are handed over to the remaining member, so they
    outlive the leaver's account instead of cascading away with it."""
    space_entry_ids = select(BacklogEntryModel.id).where(BacklogEntryModel.space_id == space_id)
    await session.execute(
        delete(SpaceEntryMemberData).where(
            SpaceEntryMemberData.user_id == user_id,
            SpaceEntryMemberData.backlog_entry_id.in_(space_entry_ids),
        )
    )
    await session.execute(
        delete(SpaceMemberModel).where(
            SpaceMemberModel.space_id == space_id, SpaceMemberModel.user_id == user_id
        )
    )
    active_left = await session.scalar(
        select(SpaceMemberModel.user_id)
        .where(SpaceMemberModel.space_id == space_id, SpaceMemberModel.status == "active")
        .limit(1)
    )
    if active_left is None:
        await session.execute(delete(SpaceModel).where(SpaceModel.id == space_id))
    else:
        for model in (BacklogEntryModel, CategoryModel, CustomStatusModel):
            await session.execute(
                update(model)
                .where(model.space_id == space_id, model.user_id == user_id)
                .values(user_id=active_left)
            )
    await session.commit()

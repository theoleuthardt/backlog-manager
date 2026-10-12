from datetime import UTC, datetime

from sqlalchemy import delete, update
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.models.user import User as UserModel
from backlog_manager_backend.models.user_avatar import UserAvatar


async def get_avatar(session: AsyncSession, user_id: int) -> UserAvatar | None:
    return await session.get(UserAvatar, user_id)


async def set_avatar(
    session: AsyncSession, user_id: int, content_type: str, data: bytes
) -> datetime:
    """Stores or replaces the picture and returns its new version stamp.
    The stamp has sub-second precision (unlike the minute-truncated
    timestamps elsewhere): a picture replaced twice within a minute must
    still get a new cache version."""
    updated_at = datetime.now(UTC).replace(tzinfo=None)
    await session.merge(UserAvatar(user_id=user_id, content_type=content_type, data=data))
    await session.execute(
        update(UserModel).where(UserModel.id == user_id).values(avatar_updated_at=updated_at)
    )
    await session.commit()
    return updated_at


async def delete_avatar(session: AsyncSession, user_id: int) -> None:
    await session.execute(delete(UserAvatar).where(UserAvatar.user_id == user_id))
    await session.execute(
        update(UserModel).where(UserModel.id == user_id).values(avatar_updated_at=None)
    )
    await session.commit()

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.passwords import verify_password
from backlog_manager_backend.models.user_backup_code import UserBackupCode


async def create_backup_codes(session: AsyncSession, user_id: int, code_hashes: list[str]) -> None:
    for code_hash in code_hashes:
        session.add(UserBackupCode(user_id=user_id, code_hash=code_hash))
    await session.commit()


async def delete_all_backup_codes(session: AsyncSession, user_id: int) -> None:
    result = await session.execute(
        select(UserBackupCode).where(UserBackupCode.user_id == user_id)
    )
    for row in result.scalars().all():
        await session.delete(row)
    await session.commit()


async def verify_and_consume_backup_code(session: AsyncSession, user_id: int, code: str) -> bool:
    """Locks the user's backup-code rows for the rest of this transaction
    before verifying, so two concurrent requests can't both read the same
    still-unconsumed code before either commits its delete."""
    result = await session.execute(
        select(UserBackupCode).where(UserBackupCode.user_id == user_id).with_for_update()
    )
    for row in result.scalars().all():
        if verify_password(row.code_hash, code):
            await session.delete(row)
            await session.commit()
            return True
    return False

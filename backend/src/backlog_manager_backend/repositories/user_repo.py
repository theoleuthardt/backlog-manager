import msgspec
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, ValidationError, handle_database_error
from backlog_manager_backend.models.user import User as UserModel
from backlog_manager_backend.schemas.user import CreateUserParams, UpdateUserParams, User
from backlog_manager_backend.utils import now_truncated_to_minute

_LAST_ADMIN_ERROR = "Cannot remove the last remaining admin"


async def _is_last_admin(session: AsyncSession, model: UserModel) -> bool:
    """Row-locks every admin (FOR UPDATE) for the rest of this
    transaction, not just counts them - otherwise two concurrent
    requests each demoting/deleting a *different* admin (with exactly
    two left) could each see "one other admin" and both proceed,
    leaving zero. The lock serializes them: the second transaction
    blocks here until the first commits or rolls back, then sees the
    up-to-date count. FOR UPDATE can't be combined with an aggregate in
    one query, hence counting the locked rows in Python instead."""
    if not model.is_admin:
        return False
    admin_ids = (
        await session.scalars(
            select(UserModel.id).where(UserModel.is_admin.is_(True)).with_for_update()
        )
    ).all()
    return list(admin_ids) == [model.id]


def _to_schema(model: UserModel) -> User:
    return User(
        id=model.id,
        name=model.username,
        email=model.email,
        password_hash=model.password_hash,
        is_admin=model.is_admin,
        totp_secret_encrypted=model.totp_secret_encrypted,
        totp_enabled=model.totp_enabled,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


async def create_user(session: AsyncSession, params: CreateUserParams) -> User:
    model = UserModel(
        username=params.username,
        email=params.email,
        password_hash=params.password_hash,
        steam_id=params.steam_id,
        is_admin=params.is_admin,
    )
    session.add(model)
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "create_user")
    await session.refresh(model)
    return _to_schema(model)


async def get_all_users(session: AsyncSession) -> list[User]:
    result = await session.execute(select(UserModel))
    return [_to_schema(row) for row in result.scalars().all()]


async def get_user_by_id(session: AsyncSession, user_id: int) -> User:
    model = await session.get(UserModel, user_id)
    if model is None:
        raise NotFoundError("User", user_id)
    return _to_schema(model)


async def get_user_by_username(session: AsyncSession, username: str) -> User | None:
    result = await session.execute(select(UserModel).where(UserModel.username == username))
    model = result.scalar_one_or_none()
    return _to_schema(model) if model is not None else None


async def get_user_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(UserModel).where(UserModel.email == email))
    model = result.scalar_one_or_none()
    return _to_schema(model) if model is not None else None


async def update_user(session: AsyncSession, params: UpdateUserParams) -> User:
    model = await session.get(UserModel, params.user_id)
    if model is None:
        raise NotFoundError("User", params.user_id)

    if params.is_admin is False and await _is_last_admin(session, model):
        raise ValidationError(_LAST_ADMIN_ERROR)

    if params.username is not msgspec.UNSET:
        model.username = params.username
    if params.email is not msgspec.UNSET:
        model.email = params.email
    if params.password_hash is not msgspec.UNSET:
        model.password_hash = params.password_hash
    if params.steam_id is not msgspec.UNSET:
        model.steam_id = params.steam_id
    if params.is_admin is not msgspec.UNSET:
        model.is_admin = params.is_admin
    if params.totp_secret_encrypted is not msgspec.UNSET:
        model.totp_secret_encrypted = params.totp_secret_encrypted
    if params.totp_enabled is not msgspec.UNSET:
        model.totp_enabled = params.totp_enabled
    model.updated_at = now_truncated_to_minute()

    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        handle_database_error(error, "update_user")
    await session.refresh(model)
    return _to_schema(model)


async def delete_user(session: AsyncSession, user_id: int) -> User:
    model = await session.get(UserModel, user_id)
    if model is None:
        raise NotFoundError("User", user_id)

    if await _is_last_admin(session, model):
        raise ValidationError(_LAST_ADMIN_ERROR)

    schema = _to_schema(model)
    await session.delete(model)
    await session.commit()
    return schema

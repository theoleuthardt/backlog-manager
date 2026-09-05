from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import NotFoundError, handle_database_error
from backlog_manager_backend.models.user import User as UserModel
from backlog_manager_backend.schemas.user import CreateUserParams, UpdateUserParams, User
from backlog_manager_backend.utils import now_truncated_to_minute


def _to_schema(model: UserModel) -> User:
    return User(
        id=model.id,
        name=model.username,
        email=model.email,
        password_hash=model.password_hash,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


async def create_user(session: AsyncSession, params: CreateUserParams) -> User:
    model = UserModel(
        username=params.username,
        email=params.email,
        password_hash=params.password_hash,
        steam_id=params.steam_id,
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

    if params.username is not None:
        model.username = params.username
    if params.email is not None:
        model.email = params.email
    if params.password_hash is not None:
        model.password_hash = params.password_hash
    if params.steam_id is not None:
        model.steam_id = params.steam_id
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

    schema = _to_schema(model)
    await session.delete(model)
    await session.commit()
    return schema

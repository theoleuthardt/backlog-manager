from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.passwords import hash_password, verify_password
from backlog_manager_backend.auth.tokens import create_access_token
from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.auth import LoginParams, RegisterParams
from backlog_manager_backend.schemas.user import CreateUserParams, User


async def register(session: AsyncSession, params: RegisterParams) -> User:
    return await user_repo.create_user(
        session,
        CreateUserParams(
            username=params.username,
            email=params.email,
            password_hash=hash_password(params.password),
            steam_id=params.steam_id,
        ),
    )


async def login(session: AsyncSession, params: LoginParams) -> str:
    """Returns a signed access token. Raises ValidationError for any
    invalid-credentials case (unknown email, wrong password, or an
    OAuth-only account with no password set) without distinguishing
    which, to avoid leaking which emails are registered."""
    user = await user_repo.get_user_by_email(session, params.email)

    if user is None or not verify_password(user.password_hash or "", params.password):
        raise ValidationError("Invalid email or password")

    return create_access_token(user.id)

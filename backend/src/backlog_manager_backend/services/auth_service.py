from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.passwords import hash_password, verify_password
from backlog_manager_backend.auth.tokens import create_access_token
from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.auth import LoginParams, RegisterParams
from backlog_manager_backend.schemas.user import CreateUserParams, User

# Verified against whenever there's no real password hash to check (unknown
# email, or an OAuth-only account), so that path still pays the same Argon2
# verification cost as a real wrong-password attempt - otherwise the
# skipped hash makes those cases measurably faster and an attacker can use
# response timing to enumerate which emails are registered.
_DUMMY_PASSWORD_HASH = hash_password("not-a-real-password-used-only-for-timing")


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
    which, in the error message or in timing."""
    user = await user_repo.get_user_by_email(session, params.email)
    password_hash = user.password_hash if user and user.password_hash else _DUMMY_PASSWORD_HASH
    password_matches = verify_password(password_hash, params.password)

    if user is None or not user.password_hash or not password_matches:
        raise ValidationError("Invalid email or password")

    return create_access_token(user.id)

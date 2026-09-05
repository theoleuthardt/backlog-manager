from litestar import Request
from litestar.di import NamedDependency
from litestar.exceptions import NotAuthorizedException
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.tokens import TokenError, decode_access_token
from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.repositories.user_repo import get_user_by_id
from backlog_manager_backend.schemas.user import User

_BEARER_PREFIX = "Bearer "


async def get_current_user(request: Request, db_session: NamedDependency[AsyncSession]) -> User:
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith(_BEARER_PREFIX):
        raise NotAuthorizedException("Missing or invalid Authorization header")

    token = auth_header.removeprefix(_BEARER_PREFIX)
    try:
        user_id = decode_access_token(token)
    except TokenError as error:
        raise NotAuthorizedException(str(error)) from error

    try:
        return await get_user_by_id(db_session, user_id)
    except NotFoundError as error:
        raise NotAuthorizedException("User not found") from error

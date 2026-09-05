from litestar import Request
from litestar.di import NamedDependency
from litestar.exceptions import NotAuthorizedException, PermissionDeniedException
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.tokens import TokenError, decode_access_token
from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.repositories.user_repo import get_user_by_id
from backlog_manager_backend.schemas.user import User

_BEARER_PREFIX = "Bearer "

# Router-level `security=` value for every router gated by get_current_user
# or require_admin - references the "BearerAuth" scheme defined once in
# app.py's OpenAPIConfig(components=...), so the generated OpenAPI spec (and
# therefore the frontend's generated client) correctly reflects which
# operations need an Authorization header.
BEARER_SECURITY_REQUIREMENT = [{"BearerAuth": []}]


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


async def require_admin(authenticated_user: NamedDependency[User]) -> User:
    """Registered to provide "current_user" (see admin_user_router),
    same as get_current_user, but must take a differently-named
    parameter - naming it "current_user" too would make the dependency
    depend on itself and blow the recursion limit at app startup. There
    is no way to grant is_admin through the API; it's set directly in
    the database by whoever operates the deployment."""
    if not authenticated_user.is_admin:
        raise PermissionDeniedException("Admin privileges required")
    return authenticated_user

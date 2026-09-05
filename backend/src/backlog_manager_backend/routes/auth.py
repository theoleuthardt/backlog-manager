from litestar import post
from litestar.di import NamedDependency
from litestar.exceptions import NotAuthorizedException
from litestar.middleware.rate_limit import RateLimitConfig
from litestar.status_codes import HTTP_200_OK
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ValidationError
from backlog_manager_backend.schemas.auth import LoginParams, TokenResponse
from backlog_manager_backend.services import auth_service

# Login is the highest-value brute-force target in the whole API (it's the
# one endpoint that turns a guessed password into a valid session) - capped
# tighter than any other endpoint, independent of whether the credentials
# guessed happen to be correct.
_login_rate_limit = RateLimitConfig(rate_limit=("minute", 10))


@post("/api/auth/login", status_code=HTTP_200_OK, middleware=[_login_rate_limit.middleware])
async def login(data: LoginParams, db_session: NamedDependency[AsyncSession]) -> TokenResponse:
    try:
        access_token = await auth_service.login(db_session, data)
    except ValidationError as error:
        raise NotAuthorizedException(str(error)) from error

    return TokenResponse(access_token=access_token)

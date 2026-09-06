from litestar import Router, post
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotAuthorizedException
from litestar.middleware.rate_limit import RateLimitConfig
from litestar.status_codes import (
    HTTP_200_OK,
    HTTP_201_CREATED,
    HTTP_204_NO_CONTENT,
    HTTP_409_CONFLICT,
)
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.schemas.auth import (
    LoginParams,
    LoginResult,
    TokenResponse,
    TwoFactorDisableParams,
    TwoFactorEnrollResponse,
    TwoFactorLoginVerifyParams,
    TwoFactorVerifyEnrollmentParams,
    TwoFactorVerifyEnrollmentResponse,
)
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import auth_service

# Login is the highest-value brute-force target in the whole API (it's the
# one endpoint that turns a guessed password into a valid session) - capped
# tighter than any other endpoint, independent of whether the credentials
# guessed happen to be correct.
_login_rate_limit = RateLimitConfig(rate_limit=("minute", 10))
# A separate instance (same values) rather than reusing _login_rate_limit -
# sharing one would let a user's earlier failed *password* attempts eat
# into their budget for entering a *TOTP code* moments later.
_two_factor_login_rate_limit = RateLimitConfig(rate_limit=("minute", 10))


@post("/api/auth/login", status_code=HTTP_200_OK, middleware=[_login_rate_limit.middleware])
async def login(data: LoginParams, db_session: NamedDependency[AsyncSession]) -> LoginResult:
    try:
        return await auth_service.login(db_session, data)
    except ValidationError as error:
        raise NotAuthorizedException(str(error)) from error


@post(
    "/api/auth/2fa/login-verify",
    status_code=HTTP_200_OK,
    middleware=[_two_factor_login_rate_limit.middleware],
)
async def login_verify(
    data: TwoFactorLoginVerifyParams, db_session: NamedDependency[AsyncSession]
) -> TokenResponse:
    try:
        access_token = await auth_service.verify_two_factor_login(
            db_session, data.challenge_token, data.code
        )
    except ValidationError as error:
        raise NotAuthorizedException(str(error)) from error
    return TokenResponse(access_token=access_token)


@post("/api/auth/2fa/enroll", status_code=HTTP_201_CREATED, security=BEARER_SECURITY_REQUIREMENT)
async def enroll_two_factor(
    db_session: NamedDependency[AsyncSession], current_user: NamedDependency[User]
) -> TwoFactorEnrollResponse:
    try:
        return await auth_service.enroll_two_factor(db_session, current_user)
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error


@post("/api/auth/2fa/verify", status_code=HTTP_200_OK, security=BEARER_SECURITY_REQUIREMENT)
async def verify_two_factor(
    data: TwoFactorVerifyEnrollmentParams,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> TwoFactorVerifyEnrollmentResponse:
    try:
        backup_codes = await auth_service.verify_two_factor_enrollment(
            db_session, current_user, data.code
        )
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error
    except ValidationError as error:
        raise ClientException(str(error)) from error
    return TwoFactorVerifyEnrollmentResponse(backup_codes=backup_codes)


@post(
    "/api/auth/2fa/disable",
    status_code=HTTP_204_NO_CONTENT,
    security=BEARER_SECURITY_REQUIREMENT,
)
async def disable_two_factor(
    data: TwoFactorDisableParams,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    try:
        await auth_service.disable_two_factor(db_session, current_user, data.password)
    except ValidationError as error:
        raise ClientException(str(error)) from error


# Same router-level-dependency gotcha as routes/user.py's user_router:
# every handler here must declare `current_user: NamedDependency[User]`
# itself, or Litestar never resolves (and therefore never runs)
# get_current_user, leaving the route silently unprotected.
two_factor_router = Router(
    path="",
    route_handlers=[enroll_two_factor, verify_two_factor, disable_two_factor],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
)

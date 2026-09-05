from litestar import post
from litestar.di import NamedDependency
from litestar.exceptions import ClientException, NotAuthorizedException
from litestar.status_codes import HTTP_200_OK, HTTP_201_CREATED, HTTP_409_CONFLICT
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.schemas.auth import (
    LoginParams,
    PublicUser,
    RegisterParams,
    TokenResponse,
)
from backlog_manager_backend.services import auth_service


@post("/api/auth/register", status_code=HTTP_201_CREATED)
async def register(data: RegisterParams, db_session: NamedDependency[AsyncSession]) -> PublicUser:
    try:
        user = await auth_service.register(db_session, data)
    except ConflictError as error:
        raise ClientException(str(error), status_code=HTTP_409_CONFLICT) from error
    return PublicUser.from_user(user)


@post("/api/auth/login", status_code=HTTP_200_OK)
async def login(data: LoginParams, db_session: NamedDependency[AsyncSession]) -> TokenResponse:
    try:
        access_token = await auth_service.login(db_session, data)
    except ValidationError as error:
        raise NotAuthorizedException(str(error)) from error

    return TokenResponse(access_token=access_token)

import structlog

from backlog_manager_backend.config import settings
from backlog_manager_backend.db import async_session
from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.repositories.user_repo import get_all_users
from backlog_manager_backend.schemas.user import CreateUserRequest
from backlog_manager_backend.services.auth_service import create_user

logger = structlog.get_logger()


async def bootstrap_initial_admin() -> None:
    """There is no public self-registration endpoint - every account
    normally has to be created by an existing admin, which is
    impossible for the very first one. If INITIAL_ADMIN_EMAIL and
    INITIAL_ADMIN_PASSWORD are set and no users exist yet, creates that
    one admin account. A no-op on every later startup, since by then a
    user (the one just created, at minimum) already exists."""
    if not settings.initial_admin_email or not settings.initial_admin_password:
        return

    async with async_session() as session:
        if await get_all_users(session):
            return

        try:
            await create_user(
                session,
                CreateUserRequest(
                    username=settings.initial_admin_email.split("@")[0],
                    email=settings.initial_admin_email,
                    password=settings.initial_admin_password,
                    is_admin=True,
                ),
            )
        except (ConflictError, ValidationError) as error:
            logger.error("Failed to bootstrap initial admin user", error=str(error))
            return

    logger.info("Created initial admin user", email=settings.initial_admin_email)

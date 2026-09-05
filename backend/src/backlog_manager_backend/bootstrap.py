import structlog

from backlog_manager_backend.config import settings
from backlog_manager_backend.db import async_session
from backlog_manager_backend.errors import ConflictError
from backlog_manager_backend.repositories.user_repo import (
    get_all_users,
    get_user_by_email,
    update_user,
)
from backlog_manager_backend.schemas.user import CreateUserRequest, UpdateUserParams
from backlog_manager_backend.services.auth_service import create_user

logger = structlog.get_logger()


async def bootstrap_initial_admin() -> None:
    """There is no public self-registration endpoint - every account
    normally has to be created by an existing admin, which is
    impossible for the very first one. If INITIAL_ADMIN_EMAIL and
    INITIAL_ADMIN_PASSWORD are set and no admin exists yet, creates one
    - promoting an existing user with that email if one already exists
    (e.g. a pre-migration account with no admin flag set), or creating
    a fresh account otherwise. A no-op once any admin exists, on every
    later startup.

    A misconfigured value (e.g. too short a password) fails startup
    rather than silently leaving the deployment without an admin -
    there would be no way to create one afterward, since every
    account-creating endpoint requires one already."""
    if not settings.initial_admin_email or not settings.initial_admin_password:
        return

    async with async_session() as session:
        if any(user.is_admin for user in await get_all_users(session)):
            return

        existing_user = await get_user_by_email(session, settings.initial_admin_email)
        if existing_user is not None:
            await update_user(session, UpdateUserParams(user_id=existing_user.id, is_admin=True))
            logger.info("Promoted existing user to admin", email=settings.initial_admin_email)
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
        except ConflictError as error:
            # Another process won a concurrent bootstrap race - fine, an
            # admin exists now either way.
            logger.error("Failed to bootstrap initial admin user", error=str(error))
            return

    logger.info("Created initial admin user", email=settings.initial_admin_email)

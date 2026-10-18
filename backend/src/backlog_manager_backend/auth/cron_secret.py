"""The endpoints a scheduler calls instead of a logged-in user (the hourly
Steam wishlist sync of the cron container in the compose files) are gated by
a static shared secret in the `X-Cron-Secret` header rather than a JWT. It is
compared with secrets.compare_digest to avoid a timing side-channel. The
secret is read from the environment variable `PRICE_CHECK_CRON_SECRET`, a name
from the time when the price sweep was its only user, kept so that no
deployment has to change its `.env`."""

import secrets

from litestar.exceptions import NotAuthorizedException

from backlog_manager_backend.config import settings

CRON_SECRET_SECURITY_REQUIREMENT = [{"CronSecret": []}]


def require_valid_cron_secret(provided: str | None) -> None:
    if not settings.cron_secret or not provided:
        raise NotAuthorizedException("Missing or unconfigured cron secret")
    if not secrets.compare_digest(provided.encode(), settings.cron_secret.encode()):
        raise NotAuthorizedException("Invalid cron secret")

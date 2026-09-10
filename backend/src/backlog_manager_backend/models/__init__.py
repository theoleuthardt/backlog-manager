"""SQLAlchemy declarative models and the shared server-side timestamp default.

TIMESTAMP_DEFAULT matches the DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP)
on every "CreatedAt"/"UpdatedAt" column in postgres/backlogmanagerdb-init.sql.
Declared as a server_default (not a Python-side default) so SQLAlchemy omits
the column from INSERT when unset, letting Postgres apply it, instead of
sending an explicit NULL."""

from sqlalchemy import text
from sqlalchemy.orm import DeclarativeBase

TIMESTAMP_DEFAULT = text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)")


class Base(DeclarativeBase):
    pass


from backlog_manager_backend.models.backlog_entry import BacklogEntry
from backlog_manager_backend.models.category import Category
from backlog_manager_backend.models.category_backlog_entry import (
    CategoryBacklogEntry,
)
from backlog_manager_backend.models.user import User
from backlog_manager_backend.models.user_backup_code import UserBackupCode

__all__ = [
    "BacklogEntry",
    "Base",
    "Category",
    "CategoryBacklogEntry",
    "User",
    "UserBackupCode",
]

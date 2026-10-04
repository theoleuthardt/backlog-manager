"""add token_version, failed_login_attempts and locked_until to users

Revision ID: d1a7c3e9f5b4
Revises: c9e3a7f1d5b2
Create Date: 2026-10-04 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd1a7c3e9f5b4'
down_revision: Union[str, Sequence[str], None] = 'c9e3a7f1d5b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. TokenVersion backs JWT revocation, the other two the
    per-account login lockout."""
    op.add_column(
        "Users",
        sa.Column("TokenVersion", sa.Integer(), nullable=False, server_default=sa.text("0")),
        schema="blm-system",
    )
    op.add_column(
        "Users",
        sa.Column(
            "FailedLoginAttempts", sa.Integer(), nullable=False, server_default=sa.text("0")
        ),
        schema="blm-system",
    )
    op.add_column(
        "Users",
        sa.Column("LockedUntil", sa.TIMESTAMP(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "LockedUntil", schema="blm-system")
    op.drop_column("Users", "FailedLoginAttempts", schema="blm-system")
    op.drop_column("Users", "TokenVersion", schema="blm-system")

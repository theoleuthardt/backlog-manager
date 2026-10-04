"""add user_backups table

Revision ID: e2b8d4f6a1c7
Revises: d1a7c3e9f5b4
Create Date: 2026-10-04 11:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'e2b8d4f6a1c7'
down_revision: Union[str, Sequence[str], None] = 'd1a7c3e9f5b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "UserBackups",
        sa.Column("BackupID", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("UserID", sa.BigInteger(), nullable=False),
        sa.Column("Kind", sa.String(length=20), nullable=False),
        sa.Column("ContentHash", sa.String(length=64), nullable=False),
        sa.Column("EntryCount", sa.Integer(), nullable=False),
        sa.Column("CategoryCount", sa.Integer(), nullable=False),
        sa.Column("Payload", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "CreatedAt",
            sa.TIMESTAMP(),
            server_default=sa.text("timezone('utc', clock_timestamp())"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["UserID"],
            ["blm-system.Users.UserID"],
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("BackupID"),
        schema="blm-system",
    )
    op.create_index(
        "idx_userbackups_userid", "UserBackups", ["UserID"], unique=False, schema="blm-system"
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("idx_userbackups_userid", table_name="UserBackups", schema="blm-system")
    op.drop_table("UserBackups", schema="blm-system")

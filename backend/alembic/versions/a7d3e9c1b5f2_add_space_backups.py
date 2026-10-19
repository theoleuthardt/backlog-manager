"""add space backups

Revision ID: a7d3e9c1b5f2
Revises: f2c8a4d6b9e3
Create Date: 2026-10-19 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'a7d3e9c1b5f2'
down_revision: Union[str, Sequence[str], None] = 'f2c8a4d6b9e3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SCHEMA = "blm-system"
UTC_CLOCK = sa.text("timezone('utc', clock_timestamp())")


def upgrade() -> None:
    """Upgrade schema. Snapshots of a shared space and the open request to
    restore one (at most one per space)."""
    op.create_table(
        "SpaceBackups",
        sa.Column("BackupID", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("SpaceID", sa.BigInteger(), nullable=False),
        sa.Column("CreatedBy", sa.BigInteger(), nullable=True),
        sa.Column("Kind", sa.String(length=20), nullable=False),
        sa.Column("Name", sa.String(length=60), nullable=True),
        sa.Column("ContentHash", sa.String(length=64), nullable=False),
        sa.Column("EntryCount", sa.Integer(), nullable=False),
        sa.Column("CategoryCount", sa.Integer(), nullable=False),
        sa.Column("Payload", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("CreatedAt", sa.DateTime(), server_default=UTC_CLOCK, nullable=False),
        sa.ForeignKeyConstraint(
            ["SpaceID"], [f"{SCHEMA}.Spaces.SpaceID"], onupdate="CASCADE", ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["CreatedBy"], [f"{SCHEMA}.Users.UserID"], onupdate="CASCADE", ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("BackupID"),
        schema=SCHEMA,
    )
    op.create_index(
        "idx_spacebackups_spaceid", "SpaceBackups", ["SpaceID"], unique=False, schema=SCHEMA
    )
    op.create_table(
        "SpaceRestoreRequests",
        sa.Column("RequestID", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("SpaceID", sa.BigInteger(), nullable=False),
        sa.Column("BackupID", sa.BigInteger(), nullable=False),
        sa.Column("RequestedBy", sa.BigInteger(), nullable=False),
        sa.Column("CreatedAt", sa.DateTime(), server_default=UTC_CLOCK, nullable=False),
        sa.ForeignKeyConstraint(
            ["SpaceID"], [f"{SCHEMA}.Spaces.SpaceID"], onupdate="CASCADE", ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["BackupID"],
            [f"{SCHEMA}.SpaceBackups.BackupID"],
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["RequestedBy"], [f"{SCHEMA}.Users.UserID"], onupdate="CASCADE", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("RequestID"),
        sa.UniqueConstraint("SpaceID"),
        schema=SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("SpaceRestoreRequests", schema=SCHEMA)
    op.drop_index("idx_spacebackups_spaceid", table_name="SpaceBackups", schema=SCHEMA)
    op.drop_table("SpaceBackups", schema=SCHEMA)

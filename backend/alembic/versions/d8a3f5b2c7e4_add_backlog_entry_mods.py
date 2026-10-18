"""add backlog_entry_mods

Revision ID: d8a3f5b2c7e4
Revises: c7d2e9f4a6b1
Create Date: 2026-10-18 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd8a3f5b2c7e4'
down_revision: Union[str, Sequence[str], None] = 'c7d2e9f4a6b1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SCHEMA = "blm-system"
TIMESTAMP_DEFAULT = sa.text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)")


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "BacklogEntryMods",
        sa.Column("ModID", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("BacklogEntryID", sa.BigInteger(), nullable=False),
        sa.Column("Name", sa.String(length=120), nullable=False),
        sa.Column("Url", sa.Text(), nullable=True),
        sa.Column("CreatedAt", sa.DateTime(), nullable=False, server_default=TIMESTAMP_DEFAULT),
        sa.Column("UpdatedAt", sa.DateTime(), nullable=False, server_default=TIMESTAMP_DEFAULT),
        sa.ForeignKeyConstraint(
            ["BacklogEntryID"],
            [f"{SCHEMA}.BacklogEntries.BacklogEntryID"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        schema=SCHEMA,
    )
    op.create_index(
        "idx_backlogentrymods_entryid",
        "BacklogEntryMods",
        ["BacklogEntryID"],
        schema=SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("idx_backlogentrymods_entryid", table_name="BacklogEntryMods", schema=SCHEMA)
    op.drop_table("BacklogEntryMods", schema=SCHEMA)

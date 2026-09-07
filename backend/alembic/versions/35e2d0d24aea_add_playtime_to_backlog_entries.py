"""add playtime to backlog entries

Revision ID: 35e2d0d24aea
Revises: 90e1dc094ba8
Create Date: 2026-09-07 12:57:14.890377

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '35e2d0d24aea'
down_revision: Union[str, Sequence[str], None] = '90e1dc094ba8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "BacklogEntries",
        sa.Column("Playtime", sa.Numeric(10, 2), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("BacklogEntries", "Playtime", schema="blm-system")

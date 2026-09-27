"""add description to backlog entries

Revision ID: 91c5f5500e73
Revises: f3b8d2a6c9e1
Create Date: 2026-09-27 22:05:44.805112

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '91c5f5500e73'
down_revision: Union[str, Sequence[str], None] = 'f3b8d2a6c9e1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "BacklogEntries",
        sa.Column("Description", sa.Text(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("BacklogEntries", "Description", schema="blm-system")

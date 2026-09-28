"""add trailer link to backlog entries

Revision ID: b5d8e2a7c4f9
Revises: 91c5f5500e73
Create Date: 2026-09-28 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b5d8e2a7c4f9'
down_revision: Union[str, Sequence[str], None] = '91c5f5500e73'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "BacklogEntries",
        sa.Column("TrailerLink", sa.Text(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("BacklogEntries", "TrailerLink", schema="blm-system")

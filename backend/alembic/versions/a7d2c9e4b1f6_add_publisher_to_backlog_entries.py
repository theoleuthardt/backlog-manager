"""add publisher to backlog entries

Revision ID: a7d2c9e4b1f6
Revises: f4c9a1d7e3b8
Create Date: 2026-10-06 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a7d2c9e4b1f6'
down_revision: Union[str, Sequence[str], None] = 'f4c9a1d7e3b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. Existing entries stay without a publisher until an IGDB sync."""
    op.add_column(
        "BacklogEntries",
        sa.Column("Publisher", sa.String(length=255), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema. Dropping the column deliberately discards the stored publishers;
    they are filled again by the next IGDB sync after an upgrade."""
    op.drop_column("BacklogEntries", "Publisher", schema="blm-system")

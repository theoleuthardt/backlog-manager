"""add steam app id to backlog entries

Revision ID: a1c9e6f3d2b7
Revises: 35e2d0d24aea
Create Date: 2026-09-07 13:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1c9e6f3d2b7'
down_revision: Union[str, Sequence[str], None] = '35e2d0d24aea'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "BacklogEntries",
        sa.Column("SteamAppId", sa.BigInteger(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("BacklogEntries", "SteamAppId", schema="blm-system")

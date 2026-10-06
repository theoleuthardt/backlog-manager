"""default theme shelfOled for new accounts

Revision ID: b3e8f1a5d9c2
Revises: a7d2c9e4b1f6
Create Date: 2026-10-06 22:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b3e8f1a5d9c2'
down_revision: Union[str, Sequence[str], None] = 'a7d2c9e4b1f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. Only the server default changes; existing users keep their stored theme."""
    op.alter_column(
        "Users",
        "Theme",
        existing_type=sa.String(length=50),
        existing_nullable=False,
        server_default="shelfOled",
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column(
        "Users",
        "Theme",
        existing_type=sa.String(length=50),
        existing_nullable=False,
        server_default="dark",
        schema="blm-system",
    )

"""add name to user_backups

Revision ID: f4c9a1d7e3b8
Revises: e2b8d4f6a1c7
Create Date: 2026-10-04 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f4c9a1d7e3b8'
down_revision: Union[str, Sequence[str], None] = 'e2b8d4f6a1c7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. Existing backups simply have no name."""
    op.add_column(
        "UserBackups",
        sa.Column("Name", sa.String(length=60), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("UserBackups", "Name", schema="blm-system")

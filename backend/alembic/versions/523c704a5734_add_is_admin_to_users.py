"""add is_admin to users

Revision ID: 523c704a5734
Revises: ff0ef16c5bb2
Create Date: 2026-09-05 20:17:16.497108

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '523c704a5734'
down_revision: Union[str, Sequence[str], None] = 'ff0ef16c5bb2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("IsAdmin", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "IsAdmin", schema="blm-system")

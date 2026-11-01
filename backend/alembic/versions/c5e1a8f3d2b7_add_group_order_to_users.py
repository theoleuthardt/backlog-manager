"""add group order to users

Revision ID: c5e1a8f3d2b7
Revises: a7d3e9c1b5f2
Create Date: 2026-11-01 11:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB


# revision identifiers, used by Alembic.
revision: str = 'c5e1a8f3d2b7'
down_revision: Union[str, Sequence[str], None] = 'a7d3e9c1b5f2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. The order of the library groups follows the account."""
    op.add_column(
        "Users",
        sa.Column("GroupOrder", JSONB, nullable=False, server_default=sa.text("'[]'::jsonb")),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "GroupOrder", schema="blm-system")

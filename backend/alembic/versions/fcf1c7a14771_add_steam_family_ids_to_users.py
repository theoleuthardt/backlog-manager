"""add steam family ids to users

Revision ID: fcf1c7a14771
Revises: 0c36c4d536c8
Create Date: 2026-09-09 23:45:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fcf1c7a14771'
down_revision: Union[str, Sequence[str], None] = '0c36c4d536c8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("SteamFamilyIds", sa.String(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "SteamFamilyIds", schema="blm-system")

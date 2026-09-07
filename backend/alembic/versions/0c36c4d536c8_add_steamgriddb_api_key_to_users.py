"""add steamgriddb api key to users

Revision ID: 0c36c4d536c8
Revises: e7b1c4f9a3d2
Create Date: 2026-09-07 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0c36c4d536c8'
down_revision: Union[str, Sequence[str], None] = 'e7b1c4f9a3d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("SteamGridDbApiKeyEncrypted", sa.String(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "SteamGridDbApiKeyEncrypted", schema="blm-system")

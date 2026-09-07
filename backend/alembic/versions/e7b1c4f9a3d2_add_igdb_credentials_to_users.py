"""add igdb credentials to users

Revision ID: e7b1c4f9a3d2
Revises: d4f8a1c2b9e3
Create Date: 2026-09-07 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7b1c4f9a3d2'
down_revision: Union[str, Sequence[str], None] = 'd4f8a1c2b9e3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("IgdbCredentialsEncrypted", sa.String(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "IgdbCredentialsEncrypted", schema="blm-system")

"""add steam api key to users

Revision ID: b7f4a2d9e1c3
Revises: a1c9e6f3d2b7
Create Date: 2026-09-07 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b7f4a2d9e1c3'
down_revision: Union[str, Sequence[str], None] = 'a1c9e6f3d2b7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("SteamApiKeyEncrypted", sa.String(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "SteamApiKeyEncrypted", schema="blm-system")

"""add steam auto import enabled to users

Revision ID: c2a5f8d4b6e1
Revises: b7f4a2d9e1c3
Create Date: 2026-09-07 16:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c2a5f8d4b6e1'
down_revision: Union[str, Sequence[str], None] = 'b7f4a2d9e1c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column(
            "SteamAutoImportEnabled", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "SteamAutoImportEnabled", schema="blm-system")

"""add steam wishlist auto sync setting and sync report to users

Revision ID: b7d3f1a9c5e2
Revises: a1c7e5d3b9f2
Create Date: 2026-10-10 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'b7d3f1a9c5e2'
down_revision: Union[str, Sequence[str], None] = 'a1c7e5d3b9f2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column(
            "SteamWishlistAutoSync",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        schema="blm-system",
    )
    op.add_column(
        "Users",
        sa.Column(
            "SteamWishlistSyncReport", postgresql.JSONB(astext_type=sa.Text()), nullable=True
        ),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "SteamWishlistSyncReport", schema="blm-system")
    op.drop_column("Users", "SteamWishlistAutoSync", schema="blm-system")

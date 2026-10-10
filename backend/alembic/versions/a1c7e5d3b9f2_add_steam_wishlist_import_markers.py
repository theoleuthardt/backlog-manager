"""add steam wishlist import markers and the shared steam app name cache

Revision ID: a1c7e5d3b9f2
Revises: f4c9a1d7e3b8
Create Date: 2026-10-10 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1c7e5d3b9f2'
down_revision: Union[str, Sequence[str], None] = 'f4c9a1d7e3b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("SteamWishlistImportedAt", sa.TIMESTAMP(), nullable=True),
        schema="blm-system",
    )
    op.add_column(
        "BacklogEntries",
        sa.Column(
            "SteamWishlistImport",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        schema="blm-system",
    )
    op.create_table(
        "SteamAppInfo",
        sa.Column("SteamAppId", sa.BigInteger(), primary_key=True),
        sa.Column("Name", sa.String(length=255), nullable=False),
        sa.Column("HeaderImage", sa.Text(), nullable=True),
        sa.Column("ResolvedAt", sa.TIMESTAMP(), nullable=False),
        schema="blm-system",
    )


def downgrade() -> None:
    op.drop_table("SteamAppInfo", schema="blm-system")
    """Downgrade schema."""
    op.drop_column("BacklogEntries", "SteamWishlistImport", schema="blm-system")
    op.drop_column("Users", "SteamWishlistImportedAt", schema="blm-system")

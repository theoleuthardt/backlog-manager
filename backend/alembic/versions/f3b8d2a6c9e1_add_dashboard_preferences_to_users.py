"""add dashboard preferences to users

Revision ID: f3b8d2a6c9e1
Revises: a3f7c9d1e4b6
Create Date: 2026-09-25 16:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'f3b8d2a6c9e1'
down_revision: Union[str, Sequence[str], None] = 'a3f7c9d1e4b6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("DefaultSort", sa.String(length=20), nullable=False, server_default="status"),
        schema="blm-system",
    )
    op.add_column(
        "Users",
        sa.Column("Theme", sa.String(length=50), nullable=False, server_default="dark"),
        schema="blm-system",
    )
    op.add_column(
        "Users",
        sa.Column(
            "CustomThemes",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "CustomThemes", schema="blm-system")
    op.drop_column("Users", "Theme", schema="blm-system")
    op.drop_column("Users", "DefaultSort", schema="blm-system")

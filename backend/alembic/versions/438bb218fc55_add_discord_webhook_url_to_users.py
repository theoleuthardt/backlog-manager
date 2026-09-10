"""add discord webhook url to users

Revision ID: 438bb218fc55
Revises: 18066ccc8b47
Create Date: 2026-09-10 20:06:22.821813

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '438bb218fc55'
down_revision: Union[str, Sequence[str], None] = '18066ccc8b47'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("DiscordWebhookUrlEncrypted", sa.String(), nullable=True),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "DiscordWebhookUrlEncrypted", schema="blm-system")

"""add setup_completed to users

Revision ID: c9e3a7f1d5b2
Revises: b5d8e2a7c4f9
Create Date: 2026-09-29 00:50:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c9e3a7f1d5b2'
down_revision: Union[str, Sequence[str], None] = 'b5d8e2a7c4f9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. Existing accounts are marked as already set up so
    only users created after this migration see the setup wizard."""
    op.add_column(
        "Users",
        sa.Column("SetupCompleted", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        schema="blm-system",
    )
    op.execute('UPDATE "blm-system"."Users" SET "SetupCompleted" = true')


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "SetupCompleted", schema="blm-system")

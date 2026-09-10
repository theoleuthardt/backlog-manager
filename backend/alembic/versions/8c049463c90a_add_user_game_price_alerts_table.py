"""add user game price alerts table

Revision ID: 8c049463c90a
Revises: 438bb218fc55
Create Date: 2026-09-10 20:07:19.535152

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8c049463c90a'
down_revision: Union[str, Sequence[str], None] = '438bb218fc55'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'UserGamePriceAlerts',
        sa.Column('UserID', sa.BigInteger(), nullable=False),
        sa.Column('SteamAppId', sa.BigInteger(), nullable=False),
        sa.Column('LastAlertedPrice', sa.Numeric(10, 2), nullable=False),
        sa.Column(
            'UpdatedAt',
            sa.DateTime(),
            server_default=sa.text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ['UserID'], ['blm-system.Users.UserID'], onupdate='CASCADE', ondelete='CASCADE'
        ),
        sa.PrimaryKeyConstraint('UserID', 'SteamAppId'),
        schema='blm-system',
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('UserGamePriceAlerts', schema='blm-system')

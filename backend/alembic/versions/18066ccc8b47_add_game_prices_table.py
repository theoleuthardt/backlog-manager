"""add game prices table

Revision ID: 18066ccc8b47
Revises: fcf1c7a14771
Create Date: 2026-09-10 19:58:22.364990

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '18066ccc8b47'
down_revision: Union[str, Sequence[str], None] = 'fcf1c7a14771'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'GamePrices',
        sa.Column('SteamAppId', sa.BigInteger(), nullable=False),
        sa.Column('CheapsharkGameId', sa.BigInteger(), nullable=True),
        sa.Column('Deals', sa.JSON(), nullable=True),
        sa.Column('CheapestPriceEver', sa.Numeric(10, 2), nullable=True),
        sa.Column('CheapestPriceEverDate', sa.Date(), nullable=True),
        sa.Column('OnSale', sa.Boolean(), server_default=sa.text('false'), nullable=False),
        sa.Column('CheckedAt', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('SteamAppId'),
        schema='blm-system',
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('GamePrices', schema='blm-system')

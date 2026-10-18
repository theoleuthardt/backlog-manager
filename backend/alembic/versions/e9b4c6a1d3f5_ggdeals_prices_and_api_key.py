"""ggdeals prices and api key

Revision ID: e9b4c6a1d3f5
Revises: d8a3f5b2c7e4
Create Date: 2026-10-18 16:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e9b4c6a1d3f5'
down_revision: Union[str, Sequence[str], None] = 'd8a3f5b2c7e4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SCHEMA = "blm-system"


def upgrade() -> None:
    """Upgrade schema. GG.deals replaces CheapShark: the cached rows have a
    different shape (four prices instead of a list of store deals), so they
    are dropped and fetched again; nothing else depends on them. Users get a
    column for their own GG.deals API key."""
    op.execute(f'DELETE FROM "{SCHEMA}"."GamePrices"')
    for column in ("CheapsharkGameId", "Deals", "CheapestPriceEver", "CheapestPriceEverDate", "OnSale"):
        op.drop_column("GamePrices", column, schema=SCHEMA)
    op.add_column("GamePrices", sa.Column("Currency", sa.String(length=3)), schema=SCHEMA)
    for column in ("CurrentRetail", "CurrentKeyshops", "HistoricalRetail", "HistoricalKeyshops"):
        op.add_column("GamePrices", sa.Column(column, sa.Numeric(10, 2)), schema=SCHEMA)
    op.add_column("GamePrices", sa.Column("Url", sa.Text()), schema=SCHEMA)
    op.add_column(
        "Users", sa.Column("GgDealsApiKeyEncrypted", sa.Text(), nullable=True), schema=SCHEMA
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("Users", "GgDealsApiKeyEncrypted", schema=SCHEMA)
    op.execute(f'DELETE FROM "{SCHEMA}"."GamePrices"')
    for column in (
        "Url",
        "HistoricalKeyshops",
        "HistoricalRetail",
        "CurrentKeyshops",
        "CurrentRetail",
        "Currency",
    ):
        op.drop_column("GamePrices", column, schema=SCHEMA)
    op.add_column("GamePrices", sa.Column("CheapsharkGameId", sa.BigInteger()), schema=SCHEMA)
    op.add_column("GamePrices", sa.Column("Deals", sa.JSON()), schema=SCHEMA)
    op.add_column("GamePrices", sa.Column("CheapestPriceEver", sa.Numeric(10, 2)), schema=SCHEMA)
    op.add_column("GamePrices", sa.Column("CheapestPriceEverDate", sa.Date()), schema=SCHEMA)
    op.add_column(
        "GamePrices",
        sa.Column("OnSale", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        schema=SCHEMA,
    )

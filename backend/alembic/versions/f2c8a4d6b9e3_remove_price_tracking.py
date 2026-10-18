"""remove price tracking

Revision ID: f2c8a4d6b9e3
Revises: e9b4c6a1d3f5
Create Date: 2026-10-18 20:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f2c8a4d6b9e3'
down_revision: Union[str, Sequence[str], None] = 'e9b4c6a1d3f5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SCHEMA = "blm-system"
TIMESTAMP_DEFAULT = sa.text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)")


def upgrade() -> None:
    """Upgrade schema. The price cache, the Discord alert state and the two
    per-user secrets of the price feature (the Discord webhook and the
    GG.deals key) are dropped with their data."""
    op.drop_table("UserGamePriceAlerts", schema=SCHEMA)
    op.drop_table("GamePrices", schema=SCHEMA)
    op.drop_column("Users", "DiscordWebhookUrlEncrypted", schema=SCHEMA)
    op.drop_column("Users", "GgDealsApiKeyEncrypted", schema=SCHEMA)


def downgrade() -> None:
    """Downgrade schema. The tables and columns come back empty."""
    op.add_column(
        "Users", sa.Column("GgDealsApiKeyEncrypted", sa.Text(), nullable=True), schema=SCHEMA
    )
    op.add_column(
        "Users", sa.Column("DiscordWebhookUrlEncrypted", sa.Text(), nullable=True), schema=SCHEMA
    )
    op.create_table(
        "GamePrices",
        sa.Column("SteamAppId", sa.BigInteger(), primary_key=True),
        sa.Column("Currency", sa.String(length=3), nullable=True),
        sa.Column("CurrentRetail", sa.Numeric(10, 2), nullable=True),
        sa.Column("CurrentKeyshops", sa.Numeric(10, 2), nullable=True),
        sa.Column("HistoricalRetail", sa.Numeric(10, 2), nullable=True),
        sa.Column("HistoricalKeyshops", sa.Numeric(10, 2), nullable=True),
        sa.Column("Url", sa.Text(), nullable=True),
        sa.Column("CheckedAt", sa.DateTime(), nullable=False),
        schema=SCHEMA,
    )
    op.create_table(
        "UserGamePriceAlerts",
        sa.Column("UserID", sa.BigInteger(), nullable=False),
        sa.Column("SteamAppId", sa.BigInteger(), nullable=False),
        sa.Column("LastAlertedPrice", sa.Numeric(10, 2), nullable=False),
        sa.Column("UpdatedAt", sa.DateTime(), server_default=TIMESTAMP_DEFAULT, nullable=False),
        sa.ForeignKeyConstraint(
            ["UserID"], [f"{SCHEMA}.Users.UserID"], onupdate="CASCADE", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("UserID", "SteamAppId"),
        schema=SCHEMA,
    )

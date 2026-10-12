"""add user avatars

Revision ID: c4e8a2d6f1b9
Revises: b7d3f1a9c5e2
Create Date: 2026-10-12 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4e8a2d6f1b9'
down_revision: Union[str, Sequence[str], None] = 'b7d3f1a9c5e2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. Existing users simply have no picture."""
    op.add_column(
        "Users",
        sa.Column("AvatarUpdatedAt", sa.TIMESTAMP(), nullable=True),
        schema="blm-system",
    )
    op.create_table(
        "UserAvatars",
        sa.Column("UserID", sa.BigInteger(), nullable=False),
        sa.Column("ContentType", sa.String(length=50), nullable=False),
        sa.Column("Data", sa.LargeBinary(), nullable=False),
        sa.ForeignKeyConstraint(
            ["UserID"],
            ["blm-system.Users.UserID"],
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("UserID"),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("UserAvatars", schema="blm-system")
    op.drop_column("Users", "AvatarUpdatedAt", schema="blm-system")

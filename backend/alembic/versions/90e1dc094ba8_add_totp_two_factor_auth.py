"""add totp two factor auth

Revision ID: 90e1dc094ba8
Revises: 523c704a5734
Create Date: 2026-09-06 22:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '90e1dc094ba8'
down_revision: Union[str, Sequence[str], None] = '523c704a5734'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "Users",
        sa.Column("TotpSecretEncrypted", sa.Text(), nullable=True),
        schema="blm-system",
    )
    op.add_column(
        "Users",
        sa.Column("TotpEnabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        schema="blm-system",
    )
    op.create_table(
        "UserBackupCodes",
        sa.Column("BackupCodeID", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("UserID", sa.BigInteger(), nullable=False),
        sa.Column("CodeHash", sa.String(length=255), nullable=False),
        sa.Column(
            "CreatedAt",
            sa.TIMESTAMP(),
            server_default=sa.text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["UserID"],
            ["blm-system.Users.UserID"],
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("BackupCodeID"),
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("UserBackupCodes", schema="blm-system")
    op.drop_column("Users", "TotpEnabled", schema="blm-system")
    op.drop_column("Users", "TotpSecretEncrypted", schema="blm-system")

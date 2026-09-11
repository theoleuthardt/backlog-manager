"""add custom statuses table

Revision ID: a3f7c9d1e4b6
Revises: 8c049463c90a
Create Date: 2026-09-11 14:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'a3f7c9d1e4b6'
down_revision: Union[str, Sequence[str], None] = '8c049463c90a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'CustomStatuses',
        sa.Column('StatusID', sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column('UserID', sa.BigInteger(), nullable=False),
        sa.Column('Name', sa.String(length=20), nullable=False),
        sa.Column(
            'CreatedAt',
            sa.DateTime(),
            server_default=sa.text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.Column(
            'UpdatedAt',
            sa.DateTime(),
            server_default=sa.text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ['UserID'], ['blm-system.Users.UserID'], onupdate='CASCADE', ondelete='CASCADE'
        ),
        sa.PrimaryKeyConstraint('StatusID'),
        sa.UniqueConstraint('UserID', 'Name', name='CustomStatuses_UserID_Name_key'),
        schema='blm-system',
    )
    op.drop_constraint('BacklogEntries_Status_check', 'BacklogEntries', schema='blm-system', type_='check')


def downgrade() -> None:
    """Downgrade schema."""
    bind = op.get_bind()
    non_default_count = bind.execute(
        sa.text(
            'SELECT COUNT(*) FROM "blm-system"."BacklogEntries" '
            "WHERE \"Status\" NOT IN ('Not Started', 'In Progress', 'Completed', 'On Hold', 'Dropped')"
        )
    ).scalar_one()
    if non_default_count:
        raise RuntimeError(
            f"Cannot downgrade: {non_default_count} BacklogEntries row(s) use a custom "
            "status not in the fixed set. Reassign or delete them to a default status "
            "before downgrading."
        )
    op.create_check_constraint(
        'BacklogEntries_Status_check',
        'BacklogEntries',
        "\"Status\" IN ('Not Started', 'In Progress', 'Completed', 'On Hold', 'Dropped')",
        schema='blm-system',
    )
    op.drop_table('CustomStatuses', schema='blm-system')
"""add shared spaces

Revision ID: e1a4c7b9d2f6
Revises: c9e3a7f1d5b2
Create Date: 2026-10-04 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'e1a4c7b9d2f6'
down_revision: Union[str, Sequence[str], None] = 'c9e3a7f1d5b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SCHEMA = 'blm-system'
TIMESTAMP_DEFAULT = sa.text("DATE_TRUNC('minute', CURRENT_TIMESTAMP)")


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'Spaces',
        sa.Column('SpaceID', sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column('CreatedAt', sa.DateTime(), server_default=TIMESTAMP_DEFAULT, nullable=False),
        sa.Column('UpdatedAt', sa.DateTime(), server_default=TIMESTAMP_DEFAULT, nullable=False),
        sa.PrimaryKeyConstraint('SpaceID'),
        schema=SCHEMA,
    )
    op.create_table(
        'SpaceMembers',
        sa.Column('SpaceID', sa.BigInteger(), nullable=False),
        sa.Column('UserID', sa.BigInteger(), nullable=False),
        sa.Column('Status', sa.String(length=10), nullable=False),
        sa.Column('CreatedAt', sa.DateTime(), server_default=TIMESTAMP_DEFAULT, nullable=False),
        sa.Column('UpdatedAt', sa.DateTime(), server_default=TIMESTAMP_DEFAULT, nullable=False),
        sa.CheckConstraint("\"Status\" IN ('invited', 'active')", name='SpaceMembers_Status_check'),
        sa.ForeignKeyConstraint(
            ['SpaceID'], [f'{SCHEMA}.Spaces.SpaceID'], onupdate='CASCADE', ondelete='CASCADE'
        ),
        sa.ForeignKeyConstraint(
            ['UserID'], [f'{SCHEMA}.Users.UserID'], onupdate='CASCADE', ondelete='CASCADE'
        ),
        sa.PrimaryKeyConstraint('SpaceID', 'UserID'),
        sa.UniqueConstraint('UserID'),
        schema=SCHEMA,
    )
    for table in ('BacklogEntries', 'Categories', 'CustomStatuses'):
        op.add_column(
            table,
            sa.Column('SpaceID', sa.BigInteger(), nullable=True),
            schema=SCHEMA,
        )
        op.create_foreign_key(
            f'{table}_SpaceID_fkey',
            table,
            'Spaces',
            ['SpaceID'],
            ['SpaceID'],
            source_schema=SCHEMA,
            referent_schema=SCHEMA,
            onupdate='CASCADE',
            ondelete='CASCADE',
        )

    op.drop_constraint('BacklogEntries_UserID_SteamAppId_key', 'BacklogEntries', schema=SCHEMA, type_='unique')
    op.create_index(
        'BacklogEntries_UserID_SteamAppId_key', 'BacklogEntries', ['UserID', 'SteamAppId'],
        unique=True, schema=SCHEMA, postgresql_where=sa.text('"SpaceID" IS NULL'),
    )
    op.create_index(
        'BacklogEntries_SpaceID_SteamAppId_key', 'BacklogEntries', ['SpaceID', 'SteamAppId'],
        unique=True, schema=SCHEMA, postgresql_where=sa.text('"SpaceID" IS NOT NULL'),
    )
    op.create_index('idx_backlogentries_spaceid', 'BacklogEntries', ['SpaceID'], schema=SCHEMA)

    op.drop_constraint('CustomStatuses_UserID_Name_key', 'CustomStatuses', schema=SCHEMA, type_='unique')
    op.create_index(
        'CustomStatuses_UserID_Name_key', 'CustomStatuses', ['UserID', 'Name'],
        unique=True, schema=SCHEMA, postgresql_where=sa.text('"SpaceID" IS NULL'),
    )
    op.create_index(
        'CustomStatuses_SpaceID_Name_key', 'CustomStatuses', ['SpaceID', 'Name'],
        unique=True, schema=SCHEMA, postgresql_where=sa.text('"SpaceID" IS NOT NULL'),
    )

    op.create_table(
        'SpaceEntryMemberData',
        sa.Column('BacklogEntryID', sa.BigInteger(), nullable=False),
        sa.Column('UserID', sa.BigInteger(), nullable=False),
        sa.Column('Playtime', sa.Numeric(10, 2), nullable=True),
        sa.Column('ReviewStars', sa.Integer(), nullable=True),
        sa.Column('Review', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(
            ['BacklogEntryID'], [f'{SCHEMA}.BacklogEntries.BacklogEntryID'],
            onupdate='CASCADE', ondelete='CASCADE',
        ),
        sa.ForeignKeyConstraint(
            ['UserID'], [f'{SCHEMA}.Users.UserID'], onupdate='CASCADE', ondelete='CASCADE'
        ),
        sa.PrimaryKeyConstraint('BacklogEntryID', 'UserID'),
        schema=SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('SpaceEntryMemberData', schema=SCHEMA)

    op.execute(f'DELETE FROM "{SCHEMA}"."CustomStatuses" WHERE "SpaceID" IS NOT NULL')
    op.drop_index('CustomStatuses_SpaceID_Name_key', table_name='CustomStatuses', schema=SCHEMA)
    op.drop_index('CustomStatuses_UserID_Name_key', table_name='CustomStatuses', schema=SCHEMA)
    op.create_unique_constraint(
        'CustomStatuses_UserID_Name_key', 'CustomStatuses', ['UserID', 'Name'], schema=SCHEMA
    )

    op.execute(f'DELETE FROM "{SCHEMA}"."BacklogEntries" WHERE "SpaceID" IS NOT NULL')
    op.drop_index('idx_backlogentries_spaceid', table_name='BacklogEntries', schema=SCHEMA)
    op.drop_index('BacklogEntries_SpaceID_SteamAppId_key', table_name='BacklogEntries', schema=SCHEMA)
    op.drop_index('BacklogEntries_UserID_SteamAppId_key', table_name='BacklogEntries', schema=SCHEMA)
    op.create_unique_constraint(
        'BacklogEntries_UserID_SteamAppId_key', 'BacklogEntries', ['UserID', 'SteamAppId'], schema=SCHEMA
    )

    op.execute(f'DELETE FROM "{SCHEMA}"."Categories" WHERE "SpaceID" IS NOT NULL')
    for table in ('CustomStatuses', 'Categories', 'BacklogEntries'):
        op.drop_constraint(f'{table}_SpaceID_fkey', table, schema=SCHEMA, type_='foreignkey')
        op.drop_column(table, 'SpaceID', schema=SCHEMA)

    op.drop_table('SpaceMembers', schema=SCHEMA)
    op.drop_table('Spaces', schema=SCHEMA)

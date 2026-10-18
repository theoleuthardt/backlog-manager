"""add owned to space_entry_member_data

Revision ID: c7d2e9f4a6b1
Revises: b3e8f1a5d9c2
Create Date: 2026-10-18 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c7d2e9f4a6b1'
down_revision: Union[str, Sequence[str], None] = 'b3e8f1a5d9c2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SCHEMA = "blm-system"


def upgrade() -> None:
    """Upgrade schema. Ownership of a shared entry belongs to each member
    now: every active member of the space gets the flag the entry had until
    now, so nobody sees a change."""
    op.add_column(
        "SpaceEntryMemberData",
        sa.Column("Owned", sa.Boolean(), nullable=True),
        schema=SCHEMA,
    )
    op.execute(
        f"""
        INSERT INTO "{SCHEMA}"."SpaceEntryMemberData" ("BacklogEntryID", "UserID", "Owned")
        SELECT e."BacklogEntryID", m."UserID", e."Owned"
        FROM "{SCHEMA}"."BacklogEntries" e
        JOIN "{SCHEMA}"."SpaceMembers" m ON m."SpaceID" = e."SpaceID" AND m."Status" = 'active'
        WHERE e."SpaceID" IS NOT NULL
        ON CONFLICT ("BacklogEntryID", "UserID") DO UPDATE SET "Owned" = EXCLUDED."Owned"
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("SpaceEntryMemberData", "Owned", schema=SCHEMA)

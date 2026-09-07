"""add unique constraint on backlog entries user id and steam app id

Revision ID: d4f8a1c2b9e3
Revises: c2a5f8d4b6e1
Create Date: 2026-09-07 17:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'd4f8a1c2b9e3'
down_revision: Union[str, Sequence[str], None] = 'c2a5f8d4b6e1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        UPDATE "blm-system"."BacklogEntries" AS entries
        SET "SteamAppId" = NULL
        WHERE "SteamAppId" IS NOT NULL
          AND "BacklogEntryID" NOT IN (
              SELECT MIN("BacklogEntryID")
              FROM "blm-system"."BacklogEntries"
              WHERE "SteamAppId" IS NOT NULL
              GROUP BY "UserID", "SteamAppId"
          )
        """
    )
    op.create_unique_constraint(
        "BacklogEntries_UserID_SteamAppId_key",
        "BacklogEntries",
        ["UserID", "SteamAppId"],
        schema="blm-system",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        "BacklogEntries_UserID_SteamAppId_key",
        "BacklogEntries",
        schema="blm-system",
        type_="unique",
    )

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, CheckConstraint, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from backlog_manager_backend.models import TIMESTAMP_DEFAULT, Base


class BacklogEntry(Base):
    """The UserID+SteamAppId unique constraint only rejects two entries
    for the same user sharing the same non-null Steam App ID - Postgres
    treats every NULL SteamAppId as distinct, so it doesn't limit how
    many entries without one a user can have."""

    __tablename__ = "BacklogEntries"
    __table_args__ = (
        CheckConstraint(
            "\"Status\" IN ('Not Started', 'In Progress', 'Completed', 'On Hold', 'Dropped')",
            name="BacklogEntries_Status_check",
        ),
        CheckConstraint(
            '"Interest" >= 1 AND "Interest" <= 10',
            name="BacklogEntries_Interest_check",
        ),
        UniqueConstraint(
            "UserID", "SteamAppId", name="BacklogEntries_UserID_SteamAppId_key"
        ),
        {"schema": "blm-system"},
    )

    id: Mapped[int] = mapped_column("BacklogEntryID", BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserID",
        BigInteger,
        ForeignKey("blm-system.Users.UserID", ondelete="CASCADE", onupdate="CASCADE"),
    )
    title: Mapped[str] = mapped_column("Title")
    genre: Mapped[str] = mapped_column("Genre")
    platform: Mapped[str] = mapped_column("Platform")
    release_date: Mapped[date | None] = mapped_column("ReleaseDate")
    image_link: Mapped[str | None] = mapped_column("ImageLink")
    main_time: Mapped[Decimal | None] = mapped_column("MainTime")
    main_plus_extra_time: Mapped[Decimal | None] = mapped_column("MainPlusExtraTime")
    completion_time: Mapped[Decimal | None] = mapped_column("CompletionTime")
    playtime: Mapped[Decimal | None] = mapped_column("Playtime")
    steam_app_id: Mapped[int | None] = mapped_column("SteamAppId", BigInteger)
    status: Mapped[str] = mapped_column("Status")
    owned: Mapped[bool] = mapped_column("Owned")
    interest: Mapped[int] = mapped_column("Interest")
    review_stars: Mapped[int | None] = mapped_column("ReviewStars")
    review: Mapped[str | None] = mapped_column("Review")
    note: Mapped[str | None] = mapped_column("Note")
    completed_at: Mapped[datetime | None] = mapped_column("CompletedAt")
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", server_default=TIMESTAMP_DEFAULT
    )
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", server_default=TIMESTAMP_DEFAULT
    )

from decimal import Decimal

import msgspec
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.models.space_entry_member_data import SpaceEntryMemberData
from backlog_manager_backend.schemas.backlog_entry import BacklogEntry


async def apply_member_data(
    session: AsyncSession, entries: list[BacklogEntry], viewer_id: int
) -> list[BacklogEntry]:
    """Overlays the viewer's own playtime, rating and review onto shared-
    space entries and exposes the other member's playtime as
    `partner_playtime`. Personal entries pass through untouched. The
    entry row's own playtime/review columns are never read for a shared
    entry, so a member who hasn't set theirs yet sees none rather than
    their partner's."""
    shared_ids = [entry.backlog_entry_id for entry in entries if entry.space_id is not None]
    if not shared_ids:
        return entries
    result = await session.execute(
        select(SpaceEntryMemberData).where(SpaceEntryMemberData.backlog_entry_id.in_(shared_ids))
    )
    own: dict[int, SpaceEntryMemberData] = {}
    partner_playtime: dict[int, Decimal | None] = {}
    for row in result.scalars().all():
        if row.user_id == viewer_id:
            own[row.backlog_entry_id] = row
        else:
            partner_playtime[row.backlog_entry_id] = row.playtime
    overlaid: list[BacklogEntry] = []
    for entry in entries:
        if entry.space_id is None:
            overlaid.append(entry)
            continue
        mine = own.get(entry.backlog_entry_id)
        overlaid.append(
            msgspec.structs.replace(
                entry,
                playtime=mine.playtime if mine else None,
                review_stars=mine.review_stars if mine else None,
                review=mine.review if mine else None,
                partner_playtime=partner_playtime.get(entry.backlog_entry_id),
            )
        )
    return overlaid


async def upsert_member_data(
    session: AsyncSession,
    backlog_entry_id: int,
    user_id: int,
    playtime: Decimal | None | msgspec.UnsetType = msgspec.UNSET,
    review_stars: int | None | msgspec.UnsetType = msgspec.UNSET,
    review: str | None | msgspec.UnsetType = msgspec.UNSET,
) -> None:
    """Same UNSET-vs-None semantics as UpdateBacklogEntryParams: an
    omitted field is left unchanged, an explicit None clears it."""
    if (
        playtime is msgspec.UNSET
        and review_stars is msgspec.UNSET
        and review is msgspec.UNSET
    ):
        return
    row = await session.get(SpaceEntryMemberData, (backlog_entry_id, user_id))
    if row is None:
        row = SpaceEntryMemberData(backlog_entry_id=backlog_entry_id, user_id=user_id)
        session.add(row)
    if playtime is not msgspec.UNSET:
        row.playtime = playtime
    if review_stars is not msgspec.UNSET:
        row.review_stars = review_stars
    if review is not msgspec.UNSET:
        row.review = review
    await session.commit()

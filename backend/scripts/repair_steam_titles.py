"""Gives the real game name, IGDB data and a cover to the entries of one user
that still carry a Steam app id as their title ("620" or "Steam App 620"), the
result of a Steam wishlist import whose store lookups failed (issue #314).

Only entries linked to a Steam app with such a title are touched; they are
marked as wishlist imports (the Steam wishlist auto sync manages them from
then on) and the user as having imported the wishlist.

Usage, in the backend container (it prints what would change and writes
nothing unless --apply is given):

    python scripts/repair_steam_titles.py --user-id 3
    python scripts/repair_steam_titles.py --user-id 3 --apply
"""

import argparse
import asyncio
import sys

from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.services import steam_service
from backlog_manager_backend.services.credentials import (
    resolve_igdb_credentials_or_none,
    resolve_steamgriddb_api_key_or_none,
)


async def run(session: AsyncSession, user_id: int, apply: bool) -> list[steam_service.TitleRepair]:
    user = await user_repo.get_user_by_id(session, user_id)
    return await steam_service.repair_steam_titles(
        session,
        user,
        steamgriddb_api_key=resolve_steamgriddb_api_key_or_none(user),
        igdb_credentials=resolve_igdb_credentials_or_none(user),
        dry_run=not apply,
    )


def format_report(repairs: list[steam_service.TitleRepair], apply: bool) -> str:
    lines = [
        f"{repair.steam_app_id}: {repair.old_title!r} -> {repair.new_title!r}"
        if repair.new_title
        else f"{repair.steam_app_id}: {repair.old_title!r} -> the store has no name for it"
        for repair in repairs
    ]
    named = sum(1 for repair in repairs if repair.new_title)
    verb = "Repaired" if apply else "Would repair"
    lines.append(f"{verb} {named} of {len(repairs)} entries.")
    return "\n".join(lines)


async def main(user_id: int, apply: bool) -> None:
    from backlog_manager_backend.db import async_session

    async with async_session() as session:
        repairs = await run(session, user_id, apply)
    print(format_report(repairs, apply))
    if not apply and repairs:
        print("Nothing was written; run again with --apply to repair them.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--user-id", type=int, required=True)
    parser.add_argument("--apply", action="store_true", help="write the changes")
    arguments = parser.parse_args()
    asyncio.run(main(arguments.user_id, arguments.apply))
    sys.exit(0)

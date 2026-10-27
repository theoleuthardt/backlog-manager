# Backups

Infrastructure-level database backups protect against losing the machine but
restore the whole database. The backend's own backups cover the other case: one user's
backlog gets damaged (a wrong bulk delete, a bad CSV import) and only that
backlog should go back.

## What is backed up

A snapshot holds one user's personal backlog content: entries (with their mods), categories
with their entry links, and custom statuses - as a versioned JSON payload
(`schemas/backup.py`, `PAYLOAD_VERSION`). It never contains account data,
credentials or API keys. Entry references inside the payload are positions,
not database ids, so identical content always hashes identically.

An entry's `steam_wishlist_import` flag is part of the snapshot (older snapshots without it restore as `false`).

Not included: account settings, themes and the profile picture, and shared
space content, which belongs to two people and has backups of its own (see
"Shared space backups" below). Shared rows carry their creator's `UserID`
plus a `SpaceID`, so every query for the personal backups in
`repositories/backup_repo.py` - including the deletes a restore starts with -
filters on `SpaceID IS NULL`; a personal restore never touches a space.

## When snapshots are taken

| Kind | Trigger | Retention |
|---|---|---|
| `auto` | Hourly scheduler tick in the API process; a user is snapshotted when their last automatic backup is older than 22 hours | 14 |
| `manual` | `POST /api/backups` ("Back up now" in Account settings) | 20 |
| `pre-restore` | Right before a restore | 5 |
| `pre-delete` | Right before `DELETE /api/backlog/entries` (delete all) | 5 |
| `pre-import` | Right before a CSV import is submitted | 5 |

Everything except `manual` is skipped when the backlog is empty (an empty
snapshot must never push real ones out through retention) or identical to
the user's latest backup of the same kind. Retention is counted per kind, so a burst of safety
snapshots cannot evict the daily ones. The scheduler is switched off with
`BACKUP_SCHEDULER_ENABLED=false` (the test suite does this). It runs inside
the API process, so the backend must run with a single worker (the
Containerfile's plain `uvicorn` command does); several workers would each run
a loop and could store duplicate automatic snapshots.

## Restoring

`POST /api/backups/{id}/restore` decodes and validates the whole payload
first, takes a `pre-restore` snapshot of the current state, then replaces
entries, categories and custom statuses in one transaction - any database
rejection rolls back to the untouched previous state. Rows are re-created with
new ids. Because of the `pre-restore` snapshot, restoring that snapshot undoes
the restore.

Any backup can carry a free-form label of up to 60 characters
(`PUT /api/backups/{id}`, "Rename" in Account settings; a blank name clears
it). The label lives in its own column, not in the payload, so renaming never
changes the snapshot or its duplicate detection, and retention ignores it.

`GET /api/backups/{id}/download` returns the payload as a JSON file for an
off-machine copy. Backups of one user are never readable by another (404).

## Shared space backups (#444)

A space has backups of its own (`SpaceBackups`, `services/space_backup_service.py`,
`repositories/space_backup_repo.py`, `routes/space_backups.py`), since its
content belongs to both members. A snapshot is the personal payload plus the
per-member fields of every entry (`member_data`: playtime, rating, review and
ownership of both members, by entry ref; `schemas/space_backup.py`), so a
restore brings both members' data back. The two backup systems share the
loading and replacing code of `backup_repo` (`load_content`,
`replace_content`), which takes the space id.

| Kind | Trigger | Retention |
|---|---|---|
| `auto` | Hourly scheduler tick (the one of the personal backups); a space is snapshotted when its last automatic backup is older than 22 hours | 14 |
| `manual` | `POST /api/space/backups`, either member | 20 |
| `pre-restore` | Right before a restore | 5 |
| `pre-delete` | Right before `DELETE /api/backlog/entries?space_id=` | 5 |

The skipping rules (empty space, unchanged content) and the per-kind retention
are the same as for the personal backups. `CreatedBy` is the member who took a
snapshot, empty for automatic ones and for a member who has left.

**A restore needs both members.** `POST /api/space/backups/{id}/restore` does
not restore: it stores a request (`SpaceRestoreRequests`, one per space) and
the other member approves it with `POST /api/space/restore-request/approve`,
which runs the restore (a `pre-restore` snapshot first, one transaction, the
approving member becomes the creator of the restored rows). The member who
asked cannot approve (409), either member can end the request with
`DELETE /api/space/restore-request` (take it back or decline), a request
lapses after 24 hours (it is deleted on the next read), a second request while
one is open is refused (409), and deleting the backup, a member leaving
(`space_repo.remove_member`) or the space going away removes the request, so
the remaining member can never approve alone. A space with a single active
member restores at once: nobody else could approve. The per-member fields of
a member who is no longer active are not restored, and when a member leaves or
deletes the account their fields are also removed from every stored snapshot of
the space (`space_backup_repo.remove_member_data`). `GET /api/space/backups`
returns the list together with the open request, which is how the client
notices a request of the partner.

**Privacy.** A download (`GET /api/space/backups/{id}/download`) and the export
only contain the caller's own per-member fields, never the partner's review or
rating (the stored snapshot has both so that a restore is complete).

**Export.** `GET /api/space/export` returns the current content of the space as
a JSON file in the format of a backup download.

App: the "Space backups" button in the toolbar of the space opens a sheet
with the list, Back up now, Export JSON and the restore request (Approve and
Decline for the partner's request, Withdraw for one's own); see
[`FLUTTER.md`](FLUTTER.md).

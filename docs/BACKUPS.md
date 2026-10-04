# Backups

The homelab already takes daily Proxmox backups of the Postgres database
(see #108). Those protect against losing the machine but restore the whole
database. The backend's own backups cover the other case: one user's
backlog gets damaged (a wrong bulk delete, a bad CSV import) and only that
backlog should go back.

## What is backed up

A snapshot holds one user's personal backlog content: entries, categories
with their entry links, and custom statuses - as a versioned JSON payload
(`schemas/backup.py`, `PAYLOAD_VERSION`). It never contains account data,
credentials or API keys. Entry references inside the payload are positions,
not database ids, so identical content always hashes identically.

Not included: account settings and themes, price-alert state (keyed by Steam
app id, unaffected by a restore), and shared space content, which belongs
to two people. Shared rows carry their creator's `UserID` plus a `SpaceID`,
so every query in `repositories/backup_repo.py` - including the deletes a
restore starts with - filters on `SpaceID IS NULL`; a restore never touches a
space. A delete-all inside a space takes no backup for the same reason.

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
`BACKUP_SCHEDULER_ENABLED=false` (the test suite does this).

## Restoring

`POST /api/backups/{id}/restore` decodes and validates the whole payload
first, takes a `pre-restore` snapshot of the current state, then replaces
entries, categories and custom statuses in one transaction - any database
rejection rolls back to the untouched previous state. Rows are re-created with
new ids. Because of the `pre-restore` snapshot, restoring that snapshot undoes
the restore.

`GET /api/backups/{id}/download` returns the payload as a JSON file for an
off-machine copy. Backups of one user are never readable by another (404).

# Architecture

This document explains how Backlog Manager is put together and *why*, for
anyone (human or agent) who wasn't there for the decisions. For the literal
directory layout and command surface, see the root [`CLAUDE.md`](../CLAUDE.md)
instead — this file is about the shape of the system, not where files live.

> The client is the Flutter desktop app in `app/` (structure in [`FLUTTER.md`](FLUTTER.md)). The earlier React/Vite + Tauri client was retired with the 0.9.13 release and moved to [`backlog-manager-legacy`](https://github.com/theoleuthardt/backlog-manager-legacy) (#287); sections below that describe it are history.

## System overview

```text
┌──────────────────────┐        REST + JWT Bearer        ┌──────────────────────┐
│  Flutter desktop app │ ──────────────────────────────► │  Litestar backend    │
│  (app/)              │ ◄────────────────────────────── │  (backend/)          │
│  - macOS, Windows,   │     generated Dart client       │  - Auth (incl. 2FA)  │
│    Linux             │                                  │  - Backlog CRUD      │
└──────────────────────┘                                  │  - CSV import/export │
                                                          │  - IGDB/HLTB/Steam/  │
                                                          │    SteamGridDB       │
                                                          └──────────┬───────────┘
                                                                     │ SQLAlchemy 2.0
                                                                     │ async + asyncpg
                                                                     ▼
                                                           ┌──────────────────┐
                                                           │   PostgreSQL      │
                                                           └──────────────────┘
```

Only the backend is meant to be hosted as a public, always-on service. The
app is installed on each desktop from the GitHub Releases and updates itself
([`APP_UPDATES.md`](APP_UPDATES.md)). The Monitor (`monitor/`,
[`MONITOR_ARCHITECTURE.md`](MONITOR_ARCHITECTURE.md)) watches the backend
from its own host.

## Why REST + JWT instead of tRPC/NextAuth

The project started as a `create-t3-app` scaffold with tRPC and NextAuth
talking directly to Postgres. That coupled the API to the Next.js process,
which became a problem once a native desktop build was wanted: a static
export has no server runtime, so there's nothing to host a tRPC endpoint or
run NextAuth middleware.

The backend was rewritten from scratch as a standalone Python/Litestar
service (issue #103, landed in #104) exposing a plain REST API described by
an OpenAPI schema. The web client of that time generated a typed client from
that schema instead of relying on tRPC's compile-time link between frontend
and backend, and auth became a JWT Bearer token checked client-side, since
there's no server-side session to check in a static export. This is what
unlocked the Tauri build, and later made the Flutter app a drop-in second
client: it generates its Dart client from the same schema
(`task app:generate-api`) and talks to the same deployed backend.

The tradeoff is that things Next.js API routes gave for free — colocated
backend logic, automatic input validation via tRPC's Zod integration — now
have to be maintained explicitly across two codebases and languages. In
exchange, the backend can be hosted, scaled, and tested independently of
whatever the client is doing, and isn't tied to Next.js's request/response
lifecycle at all.

## Backend

Litestar (async, uv-managed) with a layered structure:

- `routes/` — HTTP handlers only: parse input, call a service or repository,
  map errors to HTTP status codes. No business logic here.
- `services/` — business logic that doesn't map 1:1 to a single table (e.g.
  `game_service.search` fanning out to IGDB *and* HowLongToBeat and merging
  results; `steam_service` reconciling a Steam library against existing
  backlog entries).
- `repositories/` — SQLAlchemy 2.0 async data access, one module per entity.
  Routes and services never touch `AsyncSession` queries directly outside
  this layer.
- `models/` — SQLAlchemy declarative models, mapped onto a schema that
  predates this backend (see [Database](#database) below).
- `schemas/` — `msgspec` structs for request/response shapes. These are
  intentionally separate from `models/`: a model can gain internal columns
  (e.g. an encrypted API key) without that leaking into a response schema.
- `integrations/` — thin clients for external APIs (IGDB, HowLongToBeat,
  Steam Web API, SteamGridDB), isolated so a provider's quirks don't spread
  into `services/`.
- `auth/` — password hashing, JWT issuing/verification, TOTP 2FA, and the
  Fernet-based encryption used for per-user API keys (Steam, SteamGridDB,
  IGDB) and Steam IDs at rest.

### Per-user credentials with a server-wide fallback

Several integrations (IGDB, Steam Web API, SteamGridDB) support a per-user
API key/credential that takes priority over a server-wide one configured via
environment variables. This lets a self-hosted single-user deployment just
set the server-wide env vars and never touch per-user settings, while a
multi-user deployment lets each account bring its own key instead of sharing
rate limits against one server-wide key. The same pattern (and the same
Fernet encryption key, `STEAM_API_KEY_ENCRYPTION_KEY`) is reused across all
three rather than inventing a bespoke mechanism per integration — see
`routes/games.py::_resolve_igdb_credentials` and
`routes/steam.py::_resolve_api_key` for the two shapes it takes (IGDB needs a
client id *and* secret stored together; Steam/SteamGridDB need just one key).

### Image proxying

Game cover art and achievement icons come from origins
(`images.igdb.com`, `howlongtobeat.com`, Steam's CDNs, SteamGridDB) that
block or complicate direct hotlinking from a browser. `routes/images.py`
proxies these through the backend behind a fixed host allowlist, a
content-type allowlist (only raster image types), a size cap, and a bounded
redirect chain re-validated against the same allowlist on every hop — since
it's an unauthenticated, public endpoint, none of this can rely on the
caller being trusted.

The route returns a plain `Response` whose content type is the one of the
upstream image, so Litestar cannot infer it; the OpenAPI contract is stated
with `responses=` instead: 200 as `image/*` (the description names the five
supported types; Litestar cannot mark bytes as binary, so a generated client
types the body as a string and must not be used to fetch images), 304 for a
matching ETag, and 400 and 404 as `text/plain`. `generate_examples=False` is
needed because Litestar's generated example for bytes cannot be written as
JSON (`task backend:openapi` would fail).

### Database

The schema (`postgres/backlogmanagerdb-init.sql`) predates the Litestar
backend. Alembic (`backend/alembic/`) was introduced by *stamping* the
existing schema as the baseline migration rather than generating one
retroactively from scratch — so the migration history starts from "this is
what already exists," and every schema change since has gone through a real
Alembic revision (`task backend:migration -- "..."`).

### Testing

The backend has a real pytest suite (`task test` / `uv run pytest`) that
spins up an actual PostgreSQL instance via testcontainers rather than
mocking the database — integration-style by default, not unit tests against
a fake session. The Flutter app's tests are described in
[`FLUTTER.md`](FLUTTER.md).

## Integrations at a glance

| Integration | Used for | Auth | Fallback behavior |
|---|---|---|---|
| IGDB | Game search/metadata, cover art, genres, platforms, beat times | Twitch OAuth2 client-credentials (per-user or server-wide) | Beat-time data falls back to HowLongToBeat if IGDB has none for a game |
| HowLongToBeat | Beat-time data, cover scraping | None (scraped) | Used when IGDB has no beat-time entry for a game |
| Steam Web API | Owned-games playtime sync, library import, achievements, Family sharing | Steam Web API key (per-user or server-wide) | Sync/import endpoints 503 if no key is configured anywhere |
| SteamGridDB | Higher-quality cover art for Steam-imported games | SteamGridDB API key (per-user or server-wide) | Treated as fully optional — a missing key just skips cover lookup, never fails the request it's attached to |

### Steam wishlist import

`GetWishlist` returns bare app ids, so the names come from the Steam store, which limits how many lookups it answers. `steam_service._resolve_app_details` therefore asks in this order: the shared `SteamAppInfo` table (a name is resolved once for all users and reused for 30 days), then the store browse API in batches of 50 apps with a short pause between batches (`integrations/steam.get_store_items`), then the `appdetails` page for each app the batch did not resolve, retried with a wait when the store answers 429 or a server error. A game no lookup can name is **not** imported under a placeholder such as "Steam App <id>": the preview leaves it out, the import skips it and does not mark the wishlist as imported, so the import stays available for another try.

The wishlist import is for the first time only: `Users.SteamWishlistImportedAt` holds the date of the first complete import and the Steam page then shows a note instead of the import. Entries it creates carry `BacklogEntries.SteamWishlistImport`, so later work can tell them from games the user added by hand.

Automatic sync (opt-in, `Users.SteamWishlistAutoSync`, only after the first import): the `steam-wishlist-sync-cron` container calls `POST /api/steam/wishlist/auto-sync` every hour with the same `X-Cron-Secret` as the price check. `steam_wishlist_sync_service.sync_all` then runs `sync_user` for every opted-in user: it heals titles that are still an app id, adds wishlist games the user does not have yet and removes wishlist imports (`SteamWishlistImport`) that left the wishlist. Nothing is removed for an empty wishlist (a private profile answers with an empty list), and an imported game the user has worked with (owned or moved out of "Not Owned") is only released from the sync, never deleted. The net changes are kept in `Users.SteamWishlistSyncReport` (an added game that is removed again cancels out) until the client dismisses it with `DELETE /api/user/steam/wishlist/sync-report?updated_at=<updated_at of the report it showed>` (a report the sync extended in the meantime is kept); both clients show it once as an information-only diff after the next sign-in.

`backend/scripts/repair_steam_titles.py --user-id <id> [--apply]` repairs the entries of one user that still carry an app id as their title (the result of imports before this change): it prints what it would do and writes only with `--apply`; run it in the backend container, for example `podman exec blm_backend python scripts/repair_steam_titles.py --user-id 3`.

## Build, CI and configuration notes

Config files (compose, workflows, `pyproject.toml`) carry no inline comments;
the reasoning behind their non-obvious settings lives here.

**Compose.** `compose/compose.yml` is the local Podman
file for the PostgreSQL database and pgAdmin only; the postgres image needs the
individual `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` variables, which
must match the credentials in the app's `POSTGRES_URL`.

**Workflows.**

Every pull request workflow has a path filter, so a PR only runs the checks
of what it changes (`main` has no required status checks, so a skipped
workflow never blocks a merge):

- `backend.yml` runs the backend lint, format check and pytest on PRs that
  change `backend/` or `postgres/`.
- `tests.yml` runs the release and deploy script tests on PRs that change
  `scripts/`, `deploy/` or `.nvmrc`.
- `app.yml` checks the Flutter app on PRs that change `app/`, and
  `monitor.yml` builds and tests the Monitor on PRs that change `monitor/`.
- `build.yml` test-builds the backend container image on PRs that change
  `backend/`; it never
  pushes anything. `build-and-publish.yml` publishes it to ghcr.io, only after
  a merge to `main`, never for open pull requests.
- `release-app.yml` builds, packages and publishes the Flutter app; see
  [`FLUTTER.md`](FLUTTER.md#release-workflow).

**Backend tooling.** pytest-asyncio runs every test and fixture in one
session-scoped event loop: `db.py`'s engine is a module-level singleton bound
to a single loop, and a per-test loop (the default) causes "Event loop is
closed" errors when the pool later recycles a connection from an already
closed loop. Ruff excludes `alembic/versions`: `alembic revision
--autogenerate` produces the same boilerplate every time and holding it to the
hand-written code standard is noise.

**Node.** Node 22 (`.nvmrc`) only runs the release and deploy scripts and
their tests (`task release:test`, the "Release Script Tests" job).

## Related documents

- [`docs/FLUTTER.md`](FLUTTER.md) — the desktop app: setup, tests, packaging
  and releases.
- Root [`CLAUDE.md`](../CLAUDE.md) — commands, directory layout, coding
  conventions, and the Claude Code / issue workflow used on this repo.

## Profile pictures

A user can set a profile picture (`PUT /api/user/avatar`, raw `image/png`, `image/jpeg` or `image/webp` body, at most 512 KB, bytes checked against the declared type; `DELETE /api/user/avatar`). The bytes live in `"blm-system"."UserAvatars"`, apart from `Users`, so loading a user never loads a picture; `Users.AvatarUpdatedAt` says whether there is one and is the version a client uses to cache it. `GET /api/user/{id}/avatar` answers the owner and the other member of the same Shared Space and 404 for everyone else (the same answer as for a user without a picture), with an ETag and `Cache-Control: private, no-cache`. The row goes with the account (`ON DELETE CASCADE`). Pictures are not part of backups (`docs/BACKUPS.md`): a restore replaces the backlog content, not the profile.

## Status and ownership

"Not Owned" is one of the six built-in statuses and goes with `BacklogEntries.Owned`: `PUT /api/backlog/entries/{id}` keeps the two in step when a user changes only one of them (`services/entry_ownership.py`), so a drag between status groups, the ownership switch and a bulk status change all end in the same state, in every client. Imports (Steam, CSV) set both fields themselves and do not go through it.

# Architecture

This document explains how Backlog Manager is put together and *why*, for
anyone (human or agent) who wasn't there for the decisions. For the literal
directory layout and command surface, see the root [`CLAUDE.md`](../CLAUDE.md)
instead — this file is about the shape of the system, not where files live.

## System overview

```
┌─────────────────────┐        REST + JWT Bearer        ┌──────────────────────┐
│  Next.js frontend    │ ──────────────────────────────► │  Litestar backend    │
│  (frontend/)         │ ◄────────────────────────────── │  (backend/)          │
│  - Web build (SSR)   │        openapi-fetch client      │  - Auth (incl. 2FA)  │
│  - Tauri desktop app │                                   │  - Backlog CRUD      │
│    (static export)   │                                   │  - CSV import/export │
└──────────────────────┘                                   │  - IGDB/HLTB/Steam/  │
                                                             │    SteamGridDB       │
                                                             └──────────┬───────────┘
                                                                        │ SQLAlchemy 2.0
                                                                        │ async + asyncpg
                                                                        ▼
                                                              ┌──────────────────┐
                                                              │   PostgreSQL      │
                                                              └──────────────────┘
```

Only the backend is hosted as a public, always-on service (`blm.theocloud.dev`).
The frontend is never centrally hosted the same way — it's built once and
distributed as static assets: either the web build's static export, or bundled
into the [Tauri desktop app](TAURI.md) for macOS/Windows/Linux.

## Why REST + JWT instead of tRPC/NextAuth

The project started as a `create-t3-app` scaffold with tRPC and NextAuth
talking directly to Postgres. That coupled the API to the Next.js process,
which became a problem once a native desktop build was wanted: a static
export has no server runtime, so there's nothing to host a tRPC endpoint or
run NextAuth middleware.

The backend was rewritten from scratch as a standalone Python/Litestar
service (issue #103, landed in #104) exposing a plain REST API described by
an OpenAPI schema. The frontend generates a typed client from that schema
(`frontend/src/lib/api/schema.d.ts`, via `openapi-fetch`) instead of relying
on tRPC's compile-time link between frontend and backend. Auth became a JWT
Bearer token stored in `localStorage` and checked client-side
(`RequireAuth.tsx`), since there's no server-side session to check in a
static export. This is also what unlocked the Tauri build: the desktop app
just talks to the same deployed backend a browser would, with no
app-specific backend logic embedded in Rust.

The tradeoff is that things Next.js API routes gave for free — colocated
backend logic, automatic input validation via tRPC's Zod integration — now
have to be maintained explicitly across two codebases and languages. In
exchange, the backend can be hosted, scaled, and tested independently of
whatever the frontend is doing, and isn't tied to Next.js's request/response
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
a fake session. The frontend currently has no automated test suite; changes
there are verified manually (see the root `CLAUDE.md`'s note on testing UI
changes in a browser before calling them done).

## Frontend

Next.js 15+ (App Router). Two build outputs from one codebase:

- **Web build** (`output: "standalone"`) — a normal server-rendered Next.js
  app, containerized (see the backend's Containerfile-based deployment
  pattern) — though the frontend itself isn't centrally hosted today.
- **Tauri desktop app** (`output: "export"`, `TAURI_BUILD=1`) — a static
  export loaded into a native WebView, shipped for macOS/Windows/Linux. See
  [`docs/TAURI.md`](TAURI.md) for the full build/signing/CI story.

Both builds hit the same deployed backend over REST; the only difference is
how the frontend's own HTML/JS gets to the user's machine. This is why the
desktop build needed almost no app-specific code — see `TAURI.md`'s "How it
works" section.

State/data-fetching is React Query hooks (`src/hooks/`) wrapping a typed API
client (`src/lib/api/`), one module per backend domain, each translating the
backend's snake_case JSON into the frontend's camelCase shapes at the
boundary rather than letting snake_case leak into components.

## Integrations at a glance

| Integration | Used for | Auth | Fallback behavior |
|---|---|---|---|
| IGDB | Game search/metadata, cover art, genres, platforms, beat times | Twitch OAuth2 client-credentials (per-user or server-wide) | Beat-time data falls back to HowLongToBeat if IGDB has none for a game |
| HowLongToBeat | Beat-time data, cover scraping | None (scraped) | Used when IGDB has no beat-time entry for a game |
| Steam Web API | Owned-games playtime sync, library import, achievements, Family sharing | Steam Web API key (per-user or server-wide) | Sync/import endpoints 503 if no key is configured anywhere |
| SteamGridDB | Higher-quality cover art for Steam-imported games | SteamGridDB API key (per-user or server-wide) | Treated as fully optional — a missing key just skips cover lookup, never fails the request it's attached to |

## Related documents

- [`docs/TAURI.md`](TAURI.md) — desktop app build, signing, and CI details.
- Root [`CLAUDE.md`](../CLAUDE.md) — commands, directory layout, coding
  conventions, and the Claude Code / issue workflow used on this repo.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Backlog Manager is a video game backlog manager. The client is a Flutter desktop app in `app/` (macOS, Windows, Linux; epic #247); the backend is a standalone Python/Litestar service living in `backend/` (fully migrated off Next.js/tRPC — see issue #103/#104 for that history). The app calls the backend over REST with a JWT Bearer token. Only the backend is meant to be hosted as a public, always-on service; the app is installed from the GitHub Releases and updates itself.

A separate Spring Boot service in `monitor/` (epic #468; Spring Boot 4.1.2, Java 25, Maven wrapper) is the status and alerting service of the homelab: it watches the backend from its own LXC and does not replace it. Its design: [`docs/MONITOR_ARCHITECTURE.md`](docs/MONITOR_ARCHITECTURE.md).

The earlier React/Vite + Tauri client (`frontend/`) was retired with the 0.9.13 release and moved, with its history, CI and docs, to [`backlog-manager-legacy`](https://github.com/theoleuthardt/backlog-manager-legacy) (archived, #287). Everything about the Flutter app: [`docs/FLUTTER.md`](docs/FLUTTER.md).

Users can track games with metadata from HowLongToBeat and IGDB, organize games into categories via drag & drop, connect Steam accounts for playtime sync, and import/export CSV files.

## Commands

**Always use `task <name>` (see `Taskfile.yml`, requires [go-task](https://taskfile.dev)) when running commands in this repo, instead of calling `uv run ...` / `flutter ...` / `./mvnw ...` / `docker compose ...` directly.** It wraps the backend (uv), app (flutter) and Monitor (Maven wrapper) toolchains plus the local Postgres compose stack under one unified command surface, so any command run from Claude Code should go through it if a matching task exists. `task` (no args) lists everything available; the most common ones:

```bash
task install       # uv sync (backend) + flutter pub get (app) + Maven dependencies (monitor); needs a JDK 25
task backend:dev   # Litestar dev server (uvicorn --reload)
task db:up         # local Postgres + pgAdmin via compose.yml
task test          # backend (pytest) + app (flutter test) + monitor (JUnit) + release script (node --test, Node 22 from .nvmrc) suites
task lint          # backend (ruff) + app (flutter analyze) + monitor (javac -Xlint:all -Werror)
task app:dev       # Flutter desktop app (needs Flutter 3.47.6, see docs/FLUTTER.md)
task monitor:dev   # Monitor (Spring Boot) on :8090 against the local Postgres (task monitor:db:create once); also monitor:install, monitor:lint, monitor:test, monitor:build, monitor:format(:check)
task format        # ruff format (backend) + dart format (app) + Spotless (monitor); task format:check only verifies
task audit         # known-vulnerability scan of the locked backend dependencies
task backend:migration -- "add foo column"   # new Alembic revision
task backend:migrate                          # alembic upgrade head
```

The release and deploy scripts in `scripts/` and `deploy/` are Node (version in the root `.nvmrc`); `task release:test` runs their tests.

Backend (`backend/`, uv-managed) — every command here has a task equivalent (`task install`, `task backend:dev`, `task test`, `task lint`); listed only as the underlying toolchain:
```bash
cd backend
uv sync              # Install dependencies
uv run uvicorn backlog_manager_backend.app:app --reload --port 8000
uv run pytest        # Run tests (spins up a real Postgres via testcontainers)
uv run ruff check .  # Lint
```

`.env`/`.env.example`/`.env.prod`/`.env.prod.example` stay at the repo root since `compose.yml` and the Taskfile's `monitor:*` tasks read them there.

## Architecture

**Backend stack:** Python/Litestar, uv-managed, SQLAlchemy 2.0 async + asyncpg, full REST API (backlog CRUD, auth incl. TOTP 2FA, CSV import/export, IGDB/HowLongToBeat integrations). Lives entirely in `backend/`. This is the only piece of the app meant to be hosted as a public, always-on service. See issue #104 for the migration history off Next.js/tRPC.

**Key Directories** (all under `backend/src/backlog_manager_backend/`):
- `routes/` - Litestar HTTP handlers (`auth.py`, `backlog.py`, `backups.py`, `csv.py`, `games.py`, `igdb_sync.py`, `images.py`, `space.py`, `steam.py`, `steam_wishlist_sync.py`, `user.py`, `health.py`)
- `services/` - business logic (`auth_service.py`, `game_service.py`, `igdb_sync_service.py` (retroactive IGDB data for existing entries), `credentials.py` for the per-user-credential-with-server-fallback resolution shared by the routes, ...)
- `repositories/` - SQLAlchemy data access, one module per entity
- `models/` - SQLAlchemy declarative models
- `schemas/` - msgspec request/response structs; `types.py` holds boundary types shared across schemas (currently `HexColor`, a `#rrggbb`-validated string used by both category and theme colours)
- `integrations/` - external APIs (`igdb.py`, `howlongtobeat.py`)
- `auth/` - password hashing, JWT tokens (carry the user's `TokenVersion` for revocation), TOTP/2FA, `client_ip.py` (proxy-aware client IP for the login rate limit)

**Security:** the login rate limit keys on `CF-Connecting-IP` only for peers inside `TRUSTED_PROXY_IPS`; five failed password or 2FA attempts lock an account for 15 minutes; passwords are 12-128 characters; usernames are set as 3-32 characters of `A-Z a-z 0-9 _ - .` and e-mails need one `@` and a dotted domain (`schemas/types.py`), rejected with a 400 rather than stripped; every JSON body is sanitized before validation (`sanitize.py` via the app's `request_class`: NFC, invisible and control characters removed, edges trimmed, `password` values untouched, punctuation never stripped), and the Flutter app's Dio interceptor does the same (`lib/domain/sanitize.dart`); a password change, disabling 2FA or `POST /api/auth/logout-all` bumps `Users.TokenVersion` and thereby invalidates every issued access token; `/schema` only exists with `ENABLE_DOCS=true` (`scripts/dump_openapi_schema.py` sets it itself); startup rejects weak or placeholder secrets. Details and the deployment checklist: [`docs/SECURITY.md`](docs/SECURITY.md).

**Backups:** `UserBackups` holds versioned JSON snapshots of one user's personal entries, categories and custom statuses (`services/backup_service.py`, `repositories/backup_repo.py`, `routes/backups.py`): hourly scheduler tick creating a daily `auto` snapshot, `manual` ones, and safety snapshots before restore, delete-all and CSV import; restore is one transaction. New backlog tables must be added to the snapshot/restore code in `backup_repo.py`. A shared space has backups of its own (`SpaceBackups`, `services/space_backup_service.py`: daily `auto`, `manual` by either member, safety snapshots, JSON export; a restore needs the approval of the other member through `SpaceRestoreRequests`). Details: [`docs/BACKUPS.md`](docs/BACKUPS.md).

**Shared space:** two users can share one backlog (a "space", at most two members, invited by username; a user belongs to at most one). Entries, categories and custom statuses carry a nullable `SpaceID` (NULL = personal), and every route in `routes/backlog.py` takes an optional `space_id` query param that switches it to that space - membership is checked first and a non-member gets the same 404 as a missing space. Personal repo queries filter `SpaceID IS NULL`, so shared rows never leak into personal lists, CSV export or Steam sync. Status and categories are shared; playtime, rating, review and ownership (`Owned`, no coupling to the "Not Owned" status in a space) are per member (`SpaceEntryMemberData`, overlaid onto the entry by `space_entry_member_repo.apply_member_data`, which also exposes `partner_playtime`). Any game can live in a space, and imports (CSV, Steam library/wishlist) never write to one; the Steam playtime sync updates the space playtimes of both active members (the partner's library is read by their Steam ID with the key of the request, a partner without a Steam ID or with a private library is skipped), and the IGDB sync takes `space_id` too. Leaving a space or deleting an account hands the content the leaver created over to the remaining member (`space_repo.remove_member`, also called by `user_repo.delete_user`) and deletes the space once no active member is left; `DELETE /api/backlog/entries` with `space_id` empties the space. Each entry has a list of mods (`BacklogEntryMods`, name and optional http(s) link, `/api/backlog/entries/{id}/mods`), shared by both members in a space and part of the personal backups. Personal entries are flagged `in_shared_space` when the same Steam game (or, without a Steam App ID, a game with the same title) is also in the caller's space.

**Database:** SQLAlchemy 2.0 async models/repositories (`backend/src/backlog_manager_backend/{models,repositories,schemas}/`) against PostgreSQL (`postgres/backlogmanagerdb-init.sql`), Alembic baselined onto the existing schema (`backend/alembic/`, stamped rather than migrated from scratch) and used for all schema changes since.

**Production stack:** `compose.prod.yml` (db, backend, hourly Steam wishlist sync cron; pulls the published backend image) with `.env.prod.example` as its settings template. The backend's start command first checks the settings, waits for the database, stamps a database without an Alembic version at the head and runs `alembic upgrade head` before it starts uvicorn, so every start migrates. This is done in the container command on purpose: podman-compose (1.3 and 1.5, measured) ignores `depends_on` conditions such as `service_completed_successfully`, so a separate migration service would not be waited for. Fresh databases are created from `postgres/backlogmanagerdb-init.sql` and then stamped, which means every new migration must also update that SQL file. Deployments are started manually (`Deploy Backend` workflow, owner only, self-hosted runner, `deploy/deploy.sh` on the host): [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the reasoning behind these choices (why REST/JWT replaced tRPC/NextAuth, the per-user-credential-with-server-wide-fallback pattern shared by IGDB/Steam/SteamGridDB, the image proxy's security posture) rather than just the shape of it.

## Flutter client (`app/`)

Dart/Flutter desktop app, ported from the retired web client ([`backlog-manager-legacy`](https://github.com/theoleuthardt/backlog-manager-legacy)). Setup, running, debugging, goldens and packaging: [`docs/FLUTTER.md`](docs/FLUTTER.md).

- **Commands:** always `task app:*` (`app:install`, `app:dev`, `app:lint`, `app:test`, `app:test:update-goldens`, `app:format`, `app:format:check`, `app:build`, `app:package`, `app:icons`, `app:generate-api`), never bare `flutter`/`dart`; `task check` and `task lint` include the app.
- **Layout:** `lib/api/` (everything that talks to the backend: Dio setup, error mapping, the SSE reader, the server URL setting, the generated client in `generated/`), `lib/domain/` (pure logic and models ported from the web client's `src/lib/`, no Flutter imports), `lib/design/` (`ShelfTokens`, `ShelfTextStyles`, the Material theme builder, the atmosphere, glass and glow widgets, the UI kit in `design/widgets/`), `lib/shell/` (title bar, sidebar, status bar, shortcuts), `lib/routing/` (`go_router`, route guard, session state), `lib/auth/` (token store, auth API, the sign-in state machine) and `lib/features/<screen group>/` (so far the sign-in and setup pages and the debug gallery of the UI kit), `app.dart`; `test/` mirrors `lib/`.
- **State and routing:** Riverpod and `go_router`. Screens hold UI state only; logic that is not about widgets lives in plain Dart files with unit tests.
- **Theming:** read colours from the `ShelfTokens` `ThemeExtension` and text from `ShelfTextStyles` (`lib/design/`), never hard-coded `Color`s or font sizes.
- **Partial updates:** never send a generated request class for a partial `PUT` (it sends every field and a `null` clears the field on the backend); use a map that only has the fields that changed, like `UserUpdate`.
- **Generated API client:** `lib/api/generated/` is committed and never edited by hand. After a backend route change run `task backend:openapi`, then `task app:generate-api`, and commit the diff.
- **Tests:** test first. Logic ports keep every case of the vitest file they come from; reusable components get golden tests; goldens are only re-recorded (`task app:test:update-goldens`) for an intended visual change, with the image diff reviewed.
- **Comments:** the comment policy below applies unchanged; the allowed forms are the same, written as `///`: a doc comment on a class, function or module-level constant, or a library doc comment at the top of a file. No `//` narrative comments.
- **Lints:** `task app:lint` (strict analyzer settings and rules in `app/analysis_options.yaml`) and `task app:format:check` must pass; do not add `// ignore:` to get past a lint.

## API Testing (Bruno)

The [`bruno/`](bruno/) collection covers every backend route, organized into one folder per route module (`auth/`, `backlog/`, `csv/`, `games/`, `user/`, `admin/`, `space/`, `steam/`, `images/`, `health/`). Run `auth/Login` first — its `script:post-response` stores the access token in the shared `authToken` environment variable that every other authenticated request uses. When adding a new backend route, add a matching `.bru` request in the same change.

## Code Comments

**Do not write comments that are not real code documentation.** No narrative comments, no "why I did this" asides, no step-by-step play-by-play scattered through function bodies. This applies in every language (Python, Dart, Java, everywhere) and to every file, new or existing.

The ONLY comments allowed:
- A function/class/module docstring (Python `"""..."""` and Dart `///` — including a module docstring at the top of a file, or one attached to a module-level constant that has no enclosing function/class to hold it instead — or the top-of-function/class comment block a file already uses for the same purpose).
- A comment that continues an established convention already present in that exact file (e.g. the file already annotates every module-level cache variable one line above its declaration - matching that is fine; introducing a new one-off comment style is not).

This does not extend to non-code files (YAML/JSON/TOML config) - keep those free of narrative comments too; state configuration intent in the surrounding documentation (README/CLAUDE.md) instead of inline `#` comments in the config file itself.

If you're about to write `// this falls back to X because Y` or `# note: Z happens here` above a plain statement, expression, or const - delete it. Put that reasoning in the docstring of the enclosing function instead, or leave it out entirely if the code is self-explanatory. When genuinely unsure whether a comment qualifies, don't add it.

## Testing Philosophy

Always work test-driven: write the test that expresses the desired behavior before (or alongside) the implementation, then make the implementation satisfy it.

Once a test correctly expresses the desired behavior, treat it as fixed — do not edit or weaken that test to make a failure go away. If a test fails, the default assumption is that the code is wrong, not the test. Only change a test when the desired behavior itself has genuinely changed (and say so explicitly), never as a shortcut to get a suite green.

## Software Engineering Standards

These apply to every change in this repo, human- or agent-authored, and are
what both Claude Code and CodeRabbit (see `.coderabbit.yaml`) review against:

- **No premature abstraction.** A bug fix doesn't need a surrounding
  refactor; a one-shot operation doesn't need a helper. Three similar lines
  beat a shared abstraction built for hypothetical future callers.
- **Validate at boundaries, trust internals.** User input and external API
  responses (IGDB, Steam, HowLongToBeat, SteamGridDB) get validated at the
  point they enter the system. Internal code and framework guarantees
  (SQLAlchemy, msgspec, Litestar's own request parsing) are trusted, not
  re-checked defensively at every call site.
- **No dead code.** Delete unused functions, exports, and commented-out code
  outright rather than leaving them "in case" or prefixing with `_`/`unused`.
  Git history is the record of what existed before, not the working tree.
- **Security-conscious by default.** Never trust an unauthenticated
  endpoint's input (see `routes/images.py`'s host/content-type/size
  allowlisting for the pattern); never log or return secrets (API keys,
  password hashes, encrypted blobs) even in error paths; parameterize every
  query (SQLAlchemy Core/ORM does this — don't hand-build SQL strings).
- **Small, focused changes.** One issue, one branch, one PR (see the
  workflow below) — a PR that also happens to refactor an unrelated area
  makes review and rollback harder for no benefit tied to the issue at hand.
- **Comment policy is enforced, not aspirational** — see
  [Code Comments](#code-comments) above. A PR reintroducing narrative
  comments is a real review finding, not a style nitpick.

## Working with Claude Code

This is the loop this repo is actually built with day to day — copy it
rather than improvising a different one:

1. **Everything goes through an issue first.** Even small fixes get a
   GitHub issue before a branch exists, so there's always a title and
   description to point Claude Code at and to close automatically from the
   PR. See [Issue Management Workflow](#issue-management-workflow) below.
2. **Test-driven, always** — see [Testing Philosophy](#testing-philosophy).
   Ask Claude Code to write the failing test first, look at it, *then* ask
   for the implementation. A test is a contract once it's confirmed correct;
   don't let an agent (or yourself) loosen one just to get a run green.
3. **Use `task`, not raw `uv`/`flutter`/`./mvnw`/`docker` invocations** — see
   [Commands](#commands). This is what keeps Claude Code's tool calls
   consistent across the backend/app/Monitor split and the local Postgres
   stack, and it's what CLAUDE.md tells every agent session to prefer.
4. **Lint and format-check before calling anything done**: `task check`
   (backend, app and Monitor lint plus every format check — `task lint`
   covers lint only). The
   CodeRabbit review will flag what these catch anyway — catching it
   locally first is faster.
5. **Review every PR locally with the CodeRabbit CLI.** Right after opening
   the PR, run the `code-review` Claude Code skill on the feature branch
   (`coderabbit review --agent --base main`). This replaces CodeRabbit's
   GitHub App integration, which is deliberately not used for this repo;
   the CLI applies the same `.coderabbit.yaml` rules. CLI installation and
   one-time setup are documented in
   [`docs/CODERABBIT_CLI.md`](docs/CODERABBIT_CLI.md) — required reading
   before the first review on a new machine. Fix critical/major findings,
   commit, and push — don't merge while they're open.
6. **Every change lands via a PR.** Never close an issue directly — push the
   branch and open a PR that closes the issue (`Closes #<n>`), no matter how
   small the change.
7. **For UI changes, actually run the app** (`task app:dev`) and click through
   the feature before saying it's done. Passing type checks is not the same
   as a working feature.
8. **Keep CLAUDE.md itself current.** If you (or an agent) learn something
   about the codebase's structure or conventions that isn't written down
   here, add it — this file is the single source of truth both Claude Code
   sessions and CodeRabbit reviews are expected to already know.
9. **Commit messages and PR descriptions** follow Conventional Commits
   (`feat:`, `fix:`, `docs:`, ...) and close their issue explicitly
   (`Closes #<n>`) — see step 5 of the workflow below.

## Issue Management Workflow

When working on GitHub issues, use this workflow:

### 1. View Issue Details
```bash
gh issue view <issue-number>
gh issue view <issue-number> --json title,body,state,labels,milestone
```

### 2. Add Issue to Kanban Project

Every new issue goes onto the repo's **Kanban** GitHub Project (private, and
it stays private — `gh project` works with your authenticated user's access,
no public visibility needed). The gh CLI needs the `project` OAuth scope for
these commands: check with `gh auth status`, and if it's missing run
`gh auth refresh -s project` once per machine. Right after creating an issue,
add it and set its status to "Backlog":

```bash
item_id=$(gh project item-add 1 --owner theoleuthardt \
  --url https://github.com/theoleuthardt/backlog-manager/issues/<issue-number> \
  --format json | jq -r '.id')
gh project item-edit --project-id PVT_kwHOA5wDoM4A42Fx --id "$item_id" \
  --field-id PVTSSF_lAHOA5wDoM4A42FxzgtvlFY --single-select-option-id f75ad846
```

The Status field options:
"Backlog" `f75ad846`, "In Progress" `47fc9ee4`, "Review" `f5a30336`,
"Done" `98236657`. The item's status moves with the workflow — see step 3.

### 3. Create Branch for Issue
```bash
# Create and checkout branch named after issue
gh issue develop <issue-number> --checkout

# Or manually create branch following convention: <issue-number>-<short-description>
git checkout -b <issue-number>-<short-description>

# Then set the issue's Kanban status to "In Progress" (option id 47fc9ee4):
gh project item-edit --project-id PVT_kwHOA5wDoM4A42Fx --id "$item_id" \
  --field-id PVTSSF_lAHOA5wDoM4A42FxzgtvlFY --single-select-option-id 47fc9ee4
```

For an issue that was not just added, look up its item id and assign it to
`item_id` before any status transitions:

```bash
item_id=$(gh project item-list 1 --owner theoleuthardt --limit 500 --format json \
  | jq -r '.items[] | select(.content.number == <issue-number>) | .id')
```

(The default limit is 30, too low once the board fills up.)

### 4. Update Issue Status in Project

Move the issue's Kanban status along with the workflow (same `item-edit`
command shape as step 2, only the option id changes):

- branch created → **In Progress** (`47fc9ee4`)
- PR opened → **Review** (`f5a30336`)
- PR merged → **Done** (`98236657`)

```bash
gh project item-edit --project-id PVT_kwHOA5wDoM4A42Fx --id "$item_id" \
  --field-id PVTSSF_lAHOA5wDoM4A42FxzgtvlFY --single-select-option-id <option-id>
```

### 5. After Completing Work
```bash
# Stage and commit changes
git add .
git commit -m "fix: description of changes (#<issue-number>)"

# Push to remote
git push -u origin <branch-name>

# Create PR that auto-closes issue — always, regardless of change size
gh pr create --title "Fix: description" --body "Closes #<issue-number>"

# Review the PR's feature branch locally with CodeRabbit (replaces the GitHub App)
coderabbit review --agent --base main

# Move the Kanban item to "Review" (option id f5a30336)
gh project item-edit --project-id PVT_kwHOA5wDoM4A42Fx --id "$item_id" \
  --field-id PVTSSF_lAHOA5wDoM4A42FxzgtvlFY --single-select-option-id f5a30336
```

The CodeRabbit review runs locally after the PR is opened, via the
`code-review` Claude Code skill on the feature branch (against `main`), as a
drop-in replacement for CodeRabbit's GitHub App integration — which is not
used for this repo. The CLI applies the same `.coderabbit.yaml` rules. Fix
critical/major findings, commit, and push; the PR updates automatically. Once
the PR merges, move the Kanban item to "Done" (`98236657`).

### 6. Update Issue Metadata
```bash
# Edit title/body
gh issue edit <issue-number> --title "New title"
gh issue edit <issue-number> --body "New description"

# Add/remove labels
gh issue edit <issue-number> --add-label "bug,priority:high"
gh issue edit <issue-number> --remove-label "needs-triage"

# Assign issue
gh issue edit <issue-number> --add-assignee @me
```

### Quick Reference for Common Workflow
```bash
# Full workflow example for issue #42
gh issue view 42
gh issue develop 42 --checkout
# Kanban: item-add on creation (Backlog), item-edit to In Progress after branching,
# Review after the PR, Done after merge — IDs in steps 2-5
# ... make changes ...
git add . && git commit -m "feat: implement feature (#42)"
git push -u origin 42-feature-description
gh pr create --title "feat: implement feature" --body "Closes #42"
coderabbit review --agent --base main
```


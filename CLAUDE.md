# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Backlog Manager is a video game backlog manager. The frontend is a Next.js app (T3 Stack) living in `frontend/`; the backend is a standalone Python/Litestar service living in `backend/` (fully migrated off Next.js/tRPC — see issue #103/#104 for that history). The frontend calls the backend directly over REST with a JWT Bearer token (no NextAuth, no tRPC). Only the backend is hosted as a public, always-on service (at `blm.theocloud.dev`); the frontend ships as a Tauri desktop app built from the Next.js codebase rather than being centrally hosted the same way.

Users can track games with metadata from HowLongToBeat and IGDB, organize games into categories via drag & drop, connect Steam accounts for playtime sync, and import/export CSV files.

## Commands

**Always use `task <name>` (see `Taskfile.yml`, requires [go-task](https://taskfile.dev)) when running commands in this repo, instead of calling `npm run ...` / `uv run ...` / `docker compose ...` directly.** It wraps both the frontend (npm) and backend (uv) toolchains plus the local Postgres compose stack under one unified command surface, so any command run from Claude Code should go through it if a matching task exists. `task` (no args) lists everything available; the most common ones:

```bash
task install       # npm install (frontend) + uv sync (backend)
task dev           # Next.js dev server
task backend:dev   # Litestar dev server (uvicorn --reload)
task db:up         # local Postgres + pgAdmin via compose.yml
task test          # frontend (vitest) + backend (pytest) suites
task lint          # frontend (eslint) + backend (ruff)
task backend:migration -- "add foo column"   # new Alembic revision
task backend:migrate                          # alembic upgrade head
```

The commands below still work directly if you'd rather not use Task. Root `package.json` only has convenience scripts delegating to `frontend/` (`--prefix frontend`) - run `npm install --prefix frontend` once first, or `cd frontend` and use these directly:

```bash
# Development
npm run dev          # Start dev server with Turbo (port 3000)
npm run dev:webpack  # Start dev server with Webpack

# Build & Production
npm run build        # Build for production
npm run preview      # Build and start production server
npm run start        # Start production server

# Code Quality
npm run check        # Run lint + typecheck
npm run lint         # ESLint only
npm run lint:fix     # ESLint with auto-fix
npm run typecheck    # TypeScript check

# Formatting
npm run format:check # Check Prettier formatting
npm run format:write # Apply Prettier formatting

# Testing (run from frontend/, not delegated from root)
npx vitest run       # Run all tests once
npx vitest           # Run tests in watch mode
npx vitest run test/createReadDBTests.test.ts  # Run single test file
```

Backend (`backend/`, uv-managed):
```bash
cd backend
uv sync              # Install dependencies
uv run uvicorn backlog_manager_backend.app:app --reload --port 8000
uv run pytest        # Run tests (spins up a real Postgres via testcontainers)
uv run ruff check .  # Lint
```

`.env`/`.env.example`/`.env.prod` stay at the repo root (not inside `frontend/`) since `compose.yml` needs them there for its own variable substitution; `frontend/next.config.js` loads the root `.env` explicitly via `dotenv` for local dev.

## Architecture

**Frontend stack:** Next.js 15+ with App Router, calling the backend directly over REST via a typed `openapi-fetch` client generated from the backend's OpenAPI schema, JWT Bearer token in `localStorage` for auth (no NextAuth), Tailwind CSS + shadcn/ui components. Lives entirely in `frontend/`. Distributed as a Tauri desktop app (static export) rather than centrally hosted.

**Backend stack:** Python/Litestar, uv-managed, SQLAlchemy 2.0 async + asyncpg, full REST API (backlog CRUD, auth incl. TOTP 2FA, CSV import/export, IGDB/HowLongToBeat integrations). Lives entirely in `backend/`. This is the only piece of the app hosted as a public, always-on service, at `blm.theocloud.dev`. See issue #104 for the migration history off Next.js/tRPC.

**Path Aliases** (relative to `frontend/`):
- `~/` → `./src/*`
- `components` / `components/*` → `./src/app/_components/*`
- `shadcn_components/*` → `./src/components/*` (shadcn/ui components)

**Key Directories** (all under `frontend/`):
- `src/lib/api/` - typed REST client (`client.ts`, generated `schema.d.ts`) + one module per domain (`auth.ts`, `backlog.ts`, `csv.ts`, `games.ts`, `user.ts`, `twoFactor.ts`), each mapping the backend's snake_case responses to the frontend's camelCase shapes
- `src/hooks/` - React Query hooks wrapping `lib/api/*` calls
- `src/app/context/AuthContext.tsx` - auth state (login, 2FA challenge, current user), replaces NextAuth's `SessionProvider`
- `src/app/_components/` - React components
- `src/components/ui/` - shadcn/ui primitives
- `test/` - Vitest tests (frontend no longer has its own DB access layer to test against testcontainers - that's the backend's job now)

**Key Directories** (all under `backend/src/backlog_manager_backend/`):
- `routes/` - Litestar HTTP handlers (`auth.py`, `backlog.py`, `csv.py`, `games.py`, `user.py`, `health.py`)
- `services/` - business logic (`auth_service.py`, `game_service.py`, ...)
- `repositories/` - SQLAlchemy data access, one module per entity
- `models/` - SQLAlchemy declarative models
- `schemas/` - msgspec request/response structs
- `integrations/` - external APIs (`igdb.py`, `howlongtobeat.py`)
- `auth/` - password hashing, JWT tokens, TOTP/2FA

**Database:** SQLAlchemy 2.0 async models/repositories (`backend/src/backlog_manager_backend/{models,repositories,schemas}/`) against PostgreSQL (`postgres/backlogmanagerdb-init.sql`), Alembic baselined onto the existing schema (`backend/alembic/`, stamped rather than migrated from scratch) and used for all schema changes since. The old frontend-side raw-`pg` access layer (`frontend/src/server/db/`) no longer exists.

## ESLint Rules

The project enforces strict ESLint rules:
- Use `??` instead of `||` for nullish values
- Remove unused variables
- Don't annotate types that can be inferred

## Testing Philosophy

Always work test-driven: write the test that expresses the desired behavior before (or alongside) the implementation, then make the implementation satisfy it.

Once a test correctly expresses the desired behavior, treat it as fixed — do not edit or weaken that test to make a failure go away. If a test fails, the default assumption is that the code is wrong, not the test. Only change a test when the desired behavior itself has genuinely changed (and say so explicitly), never as a shortcut to get a suite green.

## Issue Management Workflow

When working on GitHub issues, use this workflow:

### 1. View Issue Details
```bash
gh issue view <issue-number>
gh issue view <issue-number> --json title,body,state,labels,milestone
```

### 2. Create Branch for Issue
```bash
# Create and checkout branch named after issue
gh issue develop <issue-number> --checkout

# Or manually create branch following convention: <issue-number>-<short-description>
git checkout -b <issue-number>-<short-description>
```

### 3. Update Issue Status in Project
```bash
# List project items to find item ID
gh project item-list <project-number> --owner <owner> --format json

# Update issue status in project board
gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <option-id>

# Simpler: Add labels to track status
gh issue edit <issue-number> --add-label "in progress"
gh issue edit <issue-number> --remove-label "in progress" --add-label "done"
```

### 4. After Completing Work
```bash
# Stage and commit changes
git add .
git commit -m "fix: description of changes (#<issue-number>)"

# Push to remote
git push -u origin <branch-name>

# Create PR that auto-closes issue
gh pr create --title "Fix: description" --body "Closes #<issue-number>"

# Or close issue directly if no PR needed
gh issue close <issue-number> --comment "Completed in commit <sha>"
```

### 5. Update Issue Metadata
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
# ... make changes ...
git add . && git commit -m "feat: implement feature (#42)"
git push -u origin 42-feature-description
gh pr create --title "feat: implement feature" --body "Closes #42"
```

Next.js's own agent-rules notice now lives in `frontend/AGENTS.md` (with `frontend/CLAUDE.md` pointing to it) since that's where `next dev` resolves it from after the move to `frontend/`.

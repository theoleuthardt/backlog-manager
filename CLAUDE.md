# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Backlog Manager is a video game backlog manager. It's mid-migration (see issue #103/#104): the frontend is a Next.js app (T3 Stack) living in `frontend/`, and the backend is being rewritten from Next.js/tRPC into a standalone Python/Litestar service living in `backend/`. The Litestar backend currently only has a `/health` check — all real business logic (backlog CRUD, auth, CSV import/export, IGDB/HowLongToBeat integration) still lives in `frontend/src/server/` and is served via tRPC, unchanged, until the migration's later steps land.

Users can track games with metadata from HowLongToBeat and IGDB, organize games into categories via drag & drop, connect Steam accounts for playtime sync, and import/export CSV files.

## Commands

**Preferred: `task <name>`** (see `Taskfile.yml`, requires [go-task](https://taskfile.dev)) — wraps both the frontend (npm) and backend (uv) toolchains plus the local Postgres compose stack under one command surface. `task` (no args) lists everything available; the most common ones:

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

**Frontend stack:** Next.js 15+ with App Router, tRPC for type-safe API, PostgreSQL via pg package, NextAuth v5 for authentication, Tailwind CSS + shadcn/ui components. Lives entirely in `frontend/`.

**Backend stack:** Python/Litestar, uv-managed, SQLAlchemy 2.0 async + asyncpg. Lives entirely in `backend/`. Has a full DB access layer now (`models/`, `repositories/`, `schemas/`, Alembic baselined onto the existing schema — issue #110) plus a `/health` check, but no real HTTP routes/auth yet; the frontend still talks to its own tRPC backend until that lands. See issue #104 for the full migration plan and rationale.

**Path Aliases** (relative to `frontend/`):
- `~/` → `./src/*`
- `components` / `components/*` → `./src/app/_components/*`
- `shadcn_components/*` → `./src/components/*` (shadcn/ui components)

**Key Directories** (all under `frontend/`):
- `src/server/api/routers/` - tRPC routers (backlog, user, igdb, csv)
- `src/server/services/` - Business logic services
- `src/server/db/CRUD/` - Database operations (create, read, update, delete)
- `src/server/integrations/` - External APIs (HowLongToBeat, IGDB)
- `src/app/_components/` - React components
- `src/components/ui/` - shadcn/ui primitives
- `test/` - Vitest tests with testcontainers for PostgreSQL

**tRPC Setup:**
- `publicProcedure` - Unauthenticated endpoints
- `protectedProcedure` - Requires auth session
- Routers defined in `frontend/src/server/api/root.ts`

**Database:** Two parallel access layers exist during the migration, both against the same schema (`postgres/backlogmanagerdb-init.sql`, unchanged by either):
- Frontend: direct PostgreSQL via connection pool (`frontend/src/server/db/index.ts`), no ORM — still what actually serves the app today.
- Backend: SQLAlchemy 2.0 async models/repositories (`backend/src/backlog_manager_backend/{models,repositories,schemas}/`), Alembic baselined onto the existing schema (`backend/alembic/`, stamped rather than migrated from scratch) — built, tested, not yet wired to any route.

## ESLint Rules

The project enforces strict ESLint rules:
- Use `??` instead of `||` for nullish values
- Remove unused variables
- Don't annotate types that can be inferred

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

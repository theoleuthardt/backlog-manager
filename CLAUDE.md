# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Backlog Manager is a NextJS full-stack app (T3 Stack) for managing video game backlogs. Users can track games with metadata from HowLongToBeat and IGDB, organize games into categories via drag & drop, connect Steam accounts for playtime sync, and import/export CSV files.

## Commands

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

# Testing
npx vitest run       # Run all tests once
npx vitest           # Run tests in watch mode
npx vitest run test/createReadDBTests.test.ts  # Run single test file
```

## Architecture

**Stack:** Next.js 15+ with App Router, tRPC for type-safe API, PostgreSQL via pg package, NextAuth v5 for authentication, Tailwind CSS + shadcn/ui components.

**Path Aliases:**
- `~/` → `./src/*`
- `components` / `components/*` → `./src/app/_components/*`
- `shadcn_components/*` → `./src/components/*` (shadcn/ui components)

**Key Directories:**
- `src/server/api/routers/` - tRPC routers (backlog, user, hltb, igdb, csv)
- `src/server/services/` - Business logic services
- `src/server/db/CRUD/` - Database operations (create, read, update, delete)
- `src/server/integrations/` - External APIs (HowLongToBeat, IGDB)
- `src/app/_components/` - React components
- `src/components/ui/` - shadcn/ui primitives
- `test/` - Vitest tests with testcontainers for PostgreSQL

**tRPC Setup:**
- `publicProcedure` - Unauthenticated endpoints
- `protectedProcedure` - Requires auth session
- Routers defined in `src/server/api/root.ts`

**Database:** Direct PostgreSQL via connection pool (`src/server/db/index.ts`), no ORM.

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

# Backlog Manager 🎮📒

A web-based backlog manager as NextJS full stack app with authentication and PostgreSQL database, deployed via Podman.
This is a private project of mine and still work in progress. 

## Overview 

This project implements a complete backlog manager to manage and organize games.
Users can create and manage their own backlog via their account. It stores all relevant data of
games such as name, genre, platform, status and personal notes. Users can use groups to sort their
games according to categories such as "Games I still want to play", "Games I'm currently playing" and
"Games I've already played through". This is made possible by simple drag &amp; drop.

## Features
- Create backlog entries with howlongtobeat times
- Automatic image scraping from howlongtobeat.com
- Note your own thoughts about games
- Make reviews for your completed games (optional)
- Update your backlog entries as often as you want
- Connect your Steam account for current playtimes (automatic sync)
- Sort & Filter options to organize your backlog
- Import your existing backlog from a CSV file
- Export your backlog as a CSV file (simple download)
- User authentication
- Access your backlog from anywhere (browser or native app)

## Architecture

- **Frontend:** NextJS (T3 Stack), in `frontend/`
- **Backend:** migrating from TypeScript/tRPC to Python/Litestar (`backend/`) — see issue #104. Business logic currently still lives in `frontend/src/server/` until the migration's later steps land.
- **Database:** PostgreSQL (pg-package on the frontend today; SQLAlchemy planned for the backend)
- **Deployment:** Podman/Multi-Platform Apps with Tauri

## Local Development

Requires [go-task](https://taskfile.dev) and [Podman](https://podman.io/) with a
Compose provider installed (`podman-compose`, e.g. `brew install podman-compose`
on macOS) — `podman compose` delegates to whichever provider is on your `PATH`.

```bash
task install   # npm install (frontend) + uv sync (backend)
task db:up     # start local Postgres + pgAdmin
task dev       # Next.js dev server
```

See `Taskfile.yml` (`task --list`) for the full command surface, and
`CLAUDE.md` for more detail on the project's structure and workflows.

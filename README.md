# Backlog Manager 🎮📒

A backlog manager to manage and organize games, with a Python/Litestar backend API and a Next.js frontend distributed as a Tauri desktop app.
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

- **Frontend:** NextJS, in `frontend/` — calls the backend directly over REST, see issue #104 for the migration history.
- **Backend:** Python/Litestar, in `backend/` as standalone REST API, SQLAlchemy 2.0 async + asyncpg against PostgreSQL.
- **Deployment:** only the backend is hosted as a public, always-on service, at `blm.theocloud.dev` (Podman/Containerfile-based). The frontend is not centrally hosted the same way, it ships as a Tauri desktop app built from the Next.js codebase (static export) for the various platforms.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full picture — why
REST/JWT replaced tRPC/NextAuth, how the backend is layered, the image proxy's
security posture, and how each external integration (IGDB, HowLongToBeat,
Steam, SteamGridDB) falls back when unconfigured.

## Testing

- **Backend:** `task test` (`uv run pytest`) — a real suite that spins up
  PostgreSQL via testcontainers rather than mocking the database.
- **Frontend:** no automated test suite yet; changes are verified manually in
  a browser.

## API Testing

A [Bruno](https://www.usebruno.com/) collection covering every backend route
lives in [`bruno/`](bruno/). Open the folder as a collection in Bruno, select
the `Local` environment, and run `auth/Login` first to populate the shared
`authToken` variable used by the rest of the requests.

## Local Development

Everything runs through [`go-task`](https://taskfile.dev) (`task`), which
wraps the Node and uv toolchains plus the local Podman compose stack. Install
these once before your first `task install`:

| Tool | Why |
| ---- | --- |
| [Node.js 20+](https://nodejs.org) (or [nvm](https://github.com/nvm-sh/nvm)) | runs the Next.js frontend |
| [uv](https://docs.astral.sh/uv/) | Python backend dependency and tool management |
| [go-task](https://taskfile.dev) | unified command surface for every repo command |
| [Podman](https://podman.io/) + a Compose provider | local Postgres stack (`podman-compose`, e.g. `brew install podman-compose` on macOS — `podman compose` delegates to whichever provider is on your `PATH`) |
| [GitHub CLI](https://cli.github.com/) (`gh`) | the issue → branch → PR workflow: `gh issue`, `gh pr`, authentication included |
| [Bruno](https://www.usebruno.com/) | GUI for the API request collection in [`bruno/`](bruno/) |
| [CodeRabbit CLI](https://docs.coderabbit.ai/cli) (`coderabbit`) | local code reviews of every PR — see [`docs/CODERABBIT_CLI.md`](docs/CODERABBIT_CLI.md) for installation and one-time setup |

```bash
task install   # npm install (frontend) + uv sync (backend)
task db:up     # start local Postgres + pgAdmin
task dev       # Next.js dev server
```

See `Taskfile.yml` (`task --list`) for the full command surface,
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the system design, and
[`docs/TAURI.md`](docs/TAURI.md) for the desktop app build.

## Contributing

[`CLAUDE.md`](CLAUDE.md) is the source of truth for this repo's conventions —
directory layout, coding standards, the comment policy, and the exact
issue → branch → PR workflow every change (including this project's own use
of Claude Code) follows. Read its "Working with Claude Code" section before
opening a PR.

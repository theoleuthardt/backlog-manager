# Backlog Manager 🎮📒

A backlog manager to manage and organize games, with a Python/Litestar backend API and a Flutter desktop app for macOS, Windows and Linux.
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
- Access your backlog from every desktop (macOS, Windows, Linux)

## Installing the desktop app

Download the installer for your system from the [latest release](https://github.com/theoleuthardt/backlog-manager/releases/latest); the DMG, the Windows installer and the AppImage update themselves afterwards, DEB and RPM installs only announce a new release ([`docs/APP_UPDATES.md`](docs/APP_UPDATES.md)). The installers are not code signed, so macOS and Windows warn on the first start: on macOS use right click > Open (or System Settings > Privacy & Security > Open Anyway), on Windows "More info" > "Run anyway".

## Architecture

- **App:** Flutter desktop client in `app/`, calls the backend over REST with a JWT; see [`docs/FLUTTER.md`](docs/FLUTTER.md).
- **Legacy client:** the earlier React/Vite + Tauri client was retired with the 0.9.13 release and moved to [`backlog-manager-legacy`](https://github.com/theoleuthardt/backlog-manager-legacy) (#287).
- **Backend:** Python/Litestar, in `backend/` as standalone REST API, SQLAlchemy 2.0 async + asyncpg against PostgreSQL.
- **Monitor:** Spring Boot status and alerting service in `monitor/`; see [`docs/MONITOR_ARCHITECTURE.md`](docs/MONITOR_ARCHITECTURE.md).
- **Deployment:** Container-Image on [Github Container Registry](ghcr.io) within this repo. Free to use and host yourself.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full picture — why
REST/JWT replaced tRPC/NextAuth, how the backend is layered, the image proxy's
security posture, and how each external integration (IGDB, HowLongToBeat,
Steam, SteamGridDB) falls back when unconfigured.

## Testing

- **Backend:** `task test` (`uv run pytest`) as a real suite that spins up
  PostgreSQL via testcontainers rather than mocking the database.
- **App:** `task app:test` (unit, widget and golden tests), plus
  `task app:test:integration` for the main flows; see
  [`docs/FLUTTER.md`](docs/FLUTTER.md).
- **Monitor:** `task monitor:test` (JUnit, Testcontainers).

## API Testing

A [Bruno](https://www.usebruno.com/) collection covering every backend route
lives in [`bruno/`](bruno/). Open the folder as a collection in Bruno, select
the `Local` environment, and run `auth/Login` first to populate the shared
`authToken` variable used by the rest of the requests.

## Local Development

Everything runs through [`go-task`](https://taskfile.dev) (`task`), which
wraps the uv, Flutter and Maven toolchains plus the local Podman compose stack. Install
these once before your first `task install`:

| Tool | Why |
| ---- | --- |
| [Flutter 3.47.6](https://docs.flutter.dev/get-started/install) | the desktop app in `app/` (see [`docs/FLUTTER.md`](docs/FLUTTER.md)) |
| JDK 25 | the Monitor in `monitor/` (Maven wrapper included) |
| [Node.js 22](https://nodejs.org) (or [nvm](https://github.com/nvm-sh/nvm)) | the release and deploy script tests (`task release:test`) |
| [uv](https://docs.astral.sh/uv/) | Python backend dependency and tool management |
| [go-task](https://taskfile.dev) | unified command surface for every repo command |
| [Podman](https://podman.io/) + a Compose provider | local Postgres stack (`podman-compose`, e.g. `brew install podman-compose` on macOS — `podman compose` delegates to whichever provider is on your `PATH`) |
| [GitHub CLI](https://cli.github.com/) (`gh`) | the issue → branch → PR workflow: `gh issue`, `gh pr`, authentication included |
| [Bruno](https://www.usebruno.com/) | GUI for the API request collection in [`bruno/`](bruno/) |
| [CodeRabbit CLI](https://docs.coderabbit.ai/cli) (`coderabbit`) | local code reviews of every PR — see [`docs/CODERABBIT_CLI.md`](docs/CODERABBIT_CLI.md) for installation and one-time setup |

```bash
task install       # uv sync (backend) + flutter pub get (app) + Maven dependencies (monitor)
task db:up         # start local Postgres + pgAdmin
task backend:dev   # Litestar dev server on :8000
task app:dev       # the Flutter app on this platform
```

See `Taskfile.yml` (`task --list`) for the full command surface,
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the system design, and
[`docs/FLUTTER.md`](docs/FLUTTER.md) for the desktop app build.

## Contributing

[`CLAUDE.md`](CLAUDE.md) is the source of truth for this repo's conventions: directory layout, coding standards, the comment policy, and the exact
issue → branch → PR workflow every change (including this project's own use
of Claude Code) follows. Read its "Working with Claude Code" section before
opening a PR.

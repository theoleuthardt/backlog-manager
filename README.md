# Backlog Manager 🎮📒

A backlog manager to manage and organize games, with a Python/Litestar backend API and a Flutter app for macOS, Windows, Linux, Android and iOS.
This is a private project of mine and still work in progress. 

## Overview 

This project implements a complete backlog manager to manage and organize games.
Users can create and manage their own backlog via their account. It stores all relevant data of
games such as name, genre, platform, status and personal notes. Users can use groups to sort their
games according to categories such as "Games I still want to play", "Games I'm currently playing" and
"Games I've already played through". This is made possible by simple drag &amp; drop, with the mouse
on the desktop and by holding and moving a game on a touch screen.

## Features
- Add games from a search with HowLongToBeat times and IGDB metadata (genres, platforms, release date, publisher), and fill in missing data of existing games with the IGDB sync
- Covers from HowLongToBeat, Steam and SteamGridDB, with a cover picker and a "wrong game" fix
- Statuses (including your own) and categories; a game in two categories shows in both groups
- Search, filter, sort and group your backlog, with a grid or list view
- Notes, reviews, rating, playtime and the mods you use per game
- Steam: import your library and wishlist, keep the playtimes in sync
- Import your existing backlog from a CSV file, export it as CSV or JSON
- Shared space: share one backlog with a second person, with per-member playtime, rating and review
- Backups: daily automatic snapshots, manual ones and a restore
- Account security: two-factor sign-in with backup codes, a biometric lock on mobile
- Themes: built-in ones and your own, made in the theme editor
- Command palette, random pull, duplicate finder, achievements, trailers and price lookup
- Gamepad control on handhelds such as the Retroid Pocket 6 and the AYN Odin 3, with a gliding focus selector
- The app updates itself (macOS, Windows, the Linux AppImage, Android; the other installs announce new releases) and shows what is new after an update

## Installing the app

Download the app for your system from the [latest release](https://github.com/theoleuthardt/backlog-manager/releases/latest):

| System | File | Updates |
| --- | --- | --- |
| macOS | `.dmg` | in the app |
| Windows | `.exe` installer | in the app |
| Linux | `.AppImage`, `.deb`, `.rpm` | the AppImage in the app; DEB and RPM only announce a new release |
| Android 8.0 or newer | `_android_arm64.apk` (signed) | in the app, after allowing it to install unknown apps |
| iOS 16 or newer | `_ios.ipa` (unsigned) | announced in the app; sign and install each new IPA with a signing tool such as KravaSigner |

The desktop installers are not code signed, so macOS and Windows warn on the first start: on macOS use right click > Open (or System Settings > Privacy & Security > Open Anyway), on Windows "More info" > "Run anyway". Settings > Updates has the update channel: **Stable** (the default) takes full releases only, **Preview** also takes the pre-releases. Details: [`docs/APP_UPDATES.md`](docs/APP_UPDATES.md).

## Architecture

- **App:** Flutter client in `app/` for the desktop (macOS, Windows, Linux) and mobile (Android, iOS; phones in portrait, handhelds in landscape with a gamepad), calls the backend over REST with a JWT; see [`docs/FLUTTER.md`](docs/FLUTTER.md).
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
  `task app:test:integration` for the main flows. On pull requests CI also
  runs a smoke test on an Android emulator; the "App Mobile Tour" workflow,
  started by hand, walks through the whole app on a phone and a handheld
  emulator against the real backend; see [`docs/FLUTTER.md`](docs/FLUTTER.md).
- **Monitor:** `task monitor:test` (JUnit, Testcontainers).
- **Release and deploy scripts:** `task release:test` (`node --test`).

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
| [Flutter 3.47.6](https://docs.flutter.dev/get-started/install) | the app in `app/` (see [`docs/FLUTTER.md`](docs/FLUTTER.md); the Android SDK or Xcode only for the mobile builds) |
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
[`docs/FLUTTER.md`](docs/FLUTTER.md) for the app build.

## Contributing

[`CLAUDE.md`](CLAUDE.md) is the source of truth for this repo's conventions: directory layout, coding standards, the comment policy, and the exact
issue → branch → PR workflow every change (including this project's own use
of Claude Code) follows. Read its "Working with Claude Code" section before
opening a PR.

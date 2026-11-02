# Playtime tracker

A small background program written in Rust that notices when a game runs on the desktop, measures the session and reports the time to the backend. It lives in [`tracker/`](../tracker/) and is the owner's project for learning Rust, with no deadline: the backend and the app work the same without it.

## Why

Playtime only comes from Steam today (`services/steam_service.py`). Games from GOG, Epic, emulators or without a launcher stay empty or are kept by hand. The app cannot close that gap: it does not run in the background and it has no view of the other processes on the machine.

Rust suits it, because the program runs all day, has to stay light on memory and CPU, and ships as one file without a runtime.

## How it works

```text
processes on the machine
        │  every few seconds
        ▼
matcher ──── tracker.toml (which program is which game)
        │
        ▼
sessions ─── local SQLite (start, end, reported or not)
        │  when online
        ▼
backend (adds the time to the backlog entry)
```

- **Watcher:** lists the running processes and notices when a known game starts and ends.
- **Matcher:** maps a process to a backlog entry with the mapping in `tracker.toml`.
- **Sessions:** stored on the device first, so a crash or a reboot loses at most the running session, and being offline loses nothing.
- **Reporter:** sends finished sessions to the backend and marks them as reported, so none is counted twice.

## Rules

- **Steam games stay with Steam.** The Steam sync overwrites `playtime` with Steam's value, and it also matches entries without a Steam App ID by title. A tracked Steam game would lose its time at the next sync, so the tracker leaves them out.
- **A session counts once.** A report carries an id for the session, so a retry after a lost answer adds nothing.
- **Short runs do not count.** A session below a minimum length (a launcher that opens and closes) is dropped.
- **No secrets in the config.** The token sits in the system's credential store, not in `tracker.toml`.
- **Nothing leaves the device but the sessions:** no process lists, no window titles.

## Stages

Every stage ends with something that works on its own. Stage 3 needs no backend at all.

| Stage | Result | Rust it teaches | Crates |
| --- | --- | --- | --- |
| 1. Read processes | prints the running programs | structs, `Vec`, iterators, ownership | `sysinfo` |
| 2. Know the games | reads `tracker.toml`, prints "Hades is running" | `Option`, `Result`, traits, error handling | `serde`, `toml` |
| 3. Measure sessions | notices start and end, stores them, shows a summary | enums, state machines, tests | `rusqlite` |
| 4. Report to the backend | signs in and sends finished sessions, also after being offline | async, HTTP | `tokio`, `reqwest`, `keyring` |
| 5. Comfort | tray icon, autostart, finding games from their folders | platform differences | `tray-icon` |

## What the backend needs (stage 4)

No change is needed until stage 4. Then:

- A route that adds a session to an entry, for example `POST /api/backlog/entries/{id}/sessions`, with the session id, start and duration. Adding on the server is what makes a retry safe; a plain `PUT` of the new total would lose time when two devices report.
- A table of the session ids it has seen.
- The usual follow-up of a route change: `task backend:openapi`, `task app:generate-api` and a `.bru` request.

Open question: whether a shared space gets the time too, which would go to `SpaceEntryMemberData` of the member.

## Limits

The tracker runs on macOS, Windows and Linux. It does not run on Android or iOS, which do not let an app watch other apps in the background, so a game played on a handheld is not tracked.

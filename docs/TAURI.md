# Tauri Desktop App

The frontend (`frontend/`) ships as a native desktop app via [Tauri v2](https://v2.tauri.app/), on top of the same Next.js codebase used for the web build. See issue #14 for the background on why Tauri (not Electron/Capacitor/React Native) and why this only became possible after the backend moved to a standalone Litestar service (issue #104).

## How it works

Tauri loads a static export of the frontend (`output: 'export'`) into a native WebView - there is no Next.js server running inside the app, and no separate backend logic embedded in Rust either. The app talks to the same deployed Litestar backend the web build talks to (`NEXT_PUBLIC_API_URL`, baked in at build time), exactly like a browser would - REST + JWT Bearer token in `localStorage`, no cookies, no NextAuth.

This is why the desktop build needed almost no app-specific code:
- Auth is already a client-side guard (`RequireAuth.tsx`) checking token/user state, not Next.js middleware (which doesn't run in a static export anyway).
- Game cover images are proxied through the backend's `GET /api/images/proxy` endpoint (not a Next.js API route - those don't exist in a static export either).
- There are no dynamic route segments and no server actions anywhere in the app.

## Quick start

```bash
cd frontend
npm run tauri:dev     # opens a desktop window against the Next.js dev server
npm run tauri:build   # produces installers in src-tauri/target/release/bundle/
```

`tauri:dev` starts the regular Next.js dev server (`beforeDevCommand`) and points the window at it (`devUrl`), so you get the same hot-reload as `npm run dev`. `tauri:build` runs `build:tauri` first (a static export, via `TAURI_BUILD=1` switching `next.config.js`'s `output`/`images` settings - see below), then bundles it.

## Prerequisites

### All platforms
- Node.js 20+ (already required for the web build)
- [Rust](https://www.rust-lang.org/tools/install)

### macOS
- Xcode Command Line Tools: `xcode-select --install`

### Windows
- Microsoft Visual Studio C++ Build Tools
- WebView2 (pre-installed on most Windows 10/11 systems)

### Linux
```bash
# Debian/Ubuntu
sudo apt install libwebkit2gtk-4.1-dev build-essential curl wget file \
  libssl-dev libayatana-appindicator3-dev librsvg2-dev

# Fedora
sudo dnf install webkit2gtk4.1-devel openssl-devel curl wget file \
  libappindicator-gtk3-devel librsvg2-devel

# Arch
sudo pacman -S --needed webkit2gtk base-devel curl wget file openssl \
  appmenu-gtk-module libappindicator-gtk3 librsvg
```

## Scripts

- `npm run tauri:dev` - desktop window against the dev server, hot-reload
- `npm run tauri:build` - release build + installers for the current platform
- `npm run tauri:build:debug` - debug build (faster, unoptimized, easier to troubleshoot)
- `npm run build:tauri` - just the static export step (`out/`), without invoking Tauri at all

## Configuration files

- `src-tauri/tauri.conf.json` - app identity, window settings, bundle targets. `app.windows[0].url` is `/login` (not the landing page) per issue #14's requirement that desktop/mobile builds open straight to login.
- `frontend/next.config.js` - `TAURI_BUILD=1` switches `output` to `"export"` and `images.unoptimized` to `true`; unset, it builds the normal `output: "standalone"` web/container image. Next.js has no CLI flag for an alternate config file, so this env-var branch lives in the one config instead of a second file that would need swapping in and out.
- `src-tauri/icons/` - app icons for all bundle targets (including mobile variants, for future Tauri mobile support - not currently wired up).

## CI

`.github/workflows/tauri-build.yml` builds installers for Windows, macOS and Linux on a version tag push (or manually via `workflow_dispatch`). It only builds - no code signing, no publishing. Signing needs real certificates ([Windows](https://v2.tauri.app/distribute/sign/windows/), [macOS](https://v2.tauri.app/distribute/sign/macos/), [Linux](https://v2.tauri.app/distribute/sign/linux/)) that aren't part of this repo.

## Known limitation

`tauri build`'s macOS `.dmg` step shells out to Finder/AppleScript to lay out the disk image, which needs an actual attached GUI session - it will fail in a headless/remote context even though the `.app` bundle itself builds and runs fine. Not an issue on a real interactive Mac or on GitHub's `macos-latest` runners.

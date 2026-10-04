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
- Node.js 22 (already required for the web build)
- [Rust](https://www.rust-lang.org/tools/install)

### macOS
- Xcode Command Line Tools: `xcode-select --install`

### Windows
- Microsoft Visual Studio C++ Build Tools
- WebView2 (pre-installed on most Windows 10/11 systems)

### Linux
```bash
# Debian/Ubuntu
sudo apt install libwebkit2gtk-4.1-dev libxdo-dev build-essential curl wget file \
  libssl-dev libayatana-appindicator3-dev librsvg2-dev

# Fedora
sudo dnf install webkit2gtk4.1-devel libxdo-devel openssl-devel curl wget file \
  libappindicator-gtk3-devel librsvg2-devel

# Arch
sudo pacman -S --needed webkit2gtk-4.1 base-devel curl wget file openssl \
  appmenu-gtk-module libappindicator-gtk3 librsvg xdotool
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

- `.github/workflows/tauri-build.yml` builds installers for Windows, macOS and Linux. It only builds - no OS code signing, no publishing (the updater signature below is separate and required). Signing needs real certificates ([Windows](https://v2.tauri.app/distribute/sign/windows/), [macOS](https://v2.tauri.app/distribute/sign/macos/), [Linux](https://v2.tauri.app/distribute/sign/linux/)) that aren't part of this repo. Runnable manually via `workflow_dispatch` for ad-hoc testing, or called by `release-apps.yml` below.
- `.github/workflows/release-apps.yml` is the prod release pipeline - manual (`workflow_dispatch`) only, never on a push/tag. It computes the next version automatically (patch bump on the latest `v*.*.*` tag, or `frontend/package.json`'s version if there's no tag yet), builds all three platforms via `tauri-build.yml`, and publishes a GitHub Release under that version with every platform's installer attached, plus the update payloads and `latest.json` (see below).

## Self-update

The desktop app updates itself through the official [Tauri updater plugin](https://v2.tauri.app/plugin/updater/) (issue #202) rather than a hand-rolled downloader: it already verifies a signature, replaces the installed app per platform and restarts it. On start the app checks `https://github.com/theoleuthardt/backlog-manager/releases/latest/download/latest.json` and offers to install a newer version in a toast; the account page has a manual "Check for updates" card. Neither does anything in the browser build.

- Supported: macOS (`.app.tar.gz`), Linux (AppImage), Windows (NSIS `.exe`). DEB, RPM, MSI and DMG installs have to be updated by reinstalling; `latest.json` uses the installer-specific keys `linux-x86_64-appimage` and `windows-x86_64-nsis` so those installs are never offered a payload they cannot apply (their update check reports a failure instead).
- Updates are signed with a minisign key pair, independent of OS code signing. The public key is in `tauri.conf.json` (`plugins.updater.pubkey`); the private key must be stored as the repository secret `TAURI_SIGNING_PRIVATE_KEY` (key file contents, plus `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` if it has a password). Every `tauri build` needs it because `bundle.createUpdaterArtifacts` is on. Losing the private key means installed apps can never be updated again - they would need a manual reinstall with a new public key.
- Generate a new key pair with `npx tauri signer generate -w ~/.tauri/backlog-manager-updater.key` (from `frontend/`).
- `scripts/updater-manifest.mjs` runs in `release-apps.yml` after the artifacts are downloaded: it renames the signed payloads to space-free names (GitHub rewrites spaces in asset names) and writes `latest.json` with each platform's URL and signature. It fails the release if a platform's signed payload is missing. Tests: `task release:test`.
- The npm plugin packages in `frontend/package.json` are pinned to the exact version of the matching Rust crate in `Cargo.toml` - `tauri build` refuses mismatched major/minor versions.
- Only the first release built after this change carries the updater, so installs made before it have to be reinstalled once by hand.

## Known limitation

`tauri build`'s macOS `.dmg` step shells out to Finder/AppleScript to lay out the disk image, which needs an actual attached GUI session - it will fail in a headless/remote context even though the `.app` bundle itself builds and runs fine. Not an issue on a real interactive Mac or on GitHub's `macos-latest` runners.

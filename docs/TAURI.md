# Tauri Desktop App Setup

This project now includes Tauri 2.0 support for building desktop applications on Windows, macOS, and Linux.

## Quick Start

If you're on macOS and Rust is already installed:

```bash
# Run in development mode (opens desktop window)
npm run tauri:dev

# Build production app for macOS
npm run tauri:build
```

The built app will be in: `src-tauri/target/release/bundle/macos/Backlog Manager.app`

## Prerequisites

### All Platforms
- Node.js 20+ (already required for Next.js)
- Rust (installed automatically during setup)

### Platform-Specific Requirements

#### macOS
- Xcode Command Line Tools: `xcode-select --install`

#### Windows
- Microsoft Visual Studio C++ Build Tools
- WebView2 (usually pre-installed on Windows 10/11)

#### Linux
- Development packages:
  ```bash
  # Debian/Ubuntu
  sudo apt update
  sudo apt install libwebkit2gtk-4.1-dev \
    build-essential \
    curl \
    wget \
    file \
    libssl-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev

  # Fedora
  sudo dnf install webkit2gtk4.1-devel \
    openssl-devel \
    curl \
    wget \
    file \
    libappindicator-gtk3-devel \
    librsvg2-devel

  # Arch
  sudo pacman -Syu
  sudo pacman -S --needed \
    webkit2gtk \
    base-devel \
    curl \
    wget \
    file \
    openssl \
    appmenu-gtk-module \
    libappindicator-gtk3 \
    librsvg
  ```

## Available Scripts

- `npm run tauri:dev` - Run the app in development mode (opens desktop window)
- `npm run tauri:build` - Build production desktop app
- `npm run tauri:build:debug` - Build debug version of desktop app
- `npm run build:tauri` - Build Next.js for Tauri (static export)

## Development

To run the desktop app in development mode:

```bash
npm run tauri:dev
```

This will:
1. Start the Next.js dev server
2. Open a Tauri window pointing to `http://localhost:3000`

The development build includes hot-reload for both frontend and Rust code.

## Building for Production

### macOS

```bash
npm run tauri:build
```

Output: `src-tauri/target/release/bundle/macos/Backlog Manager.app`

### Windows

On a Windows machine:
```bash
npm run tauri:build
```

Output: `src-tauri/target/release/bundle/msi/Backlog Manager_0.1.0_x64_en-US.msi`

### Linux

On a Linux machine:
```bash
npm run tauri:build
```

Output formats:
- `.deb` (Debian/Ubuntu)
- `.AppImage` (universal)
- `.rpm` (Fedora/RHEL)

## Important Considerations

### Server-Side Features vs Static Export

This Next.js app currently uses:
- Server-side rendering (SSR)
- API routes (tRPC)
- Database connections (PostgreSQL)
- Authentication (next-auth)

**Tauri requires a static build** (no server), which means:

1. **Current Setup**: The `next.config.tauri.js` configures static export
2. **Limitations**: Server-side features won't work in the desktop app
3. **Solutions**:
   - Option A: Refactor to use Tauri commands (Rust backend) instead of tRPC
   - Option B: Connect desktop app to a separate deployed backend
   - Option C: Use a hybrid approach with embedded Node.js server (complex)

### Recommended Architecture for Desktop App

For a fully functional desktop app, consider:

1. **Move backend logic to Tauri commands** (Rust)
   - Database operations via Tauri commands
   - Authentication via Tauri secure storage
   - Use SQLite or embedded database

2. **Keep frontend as static Next.js**
   - Use React Query to call Tauri commands
   - Convert tRPC calls to Tauri invoke calls

3. **Example Tauri Command** (in `src-tauri/src/lib.rs`):
   ```rust
   #[tauri::command]
   fn get_backlog_items() -> Vec<BacklogItem> {
       // Database operations here
       vec![]
   }
   ```

## GitHub Actions Workflow (Future)

For automated builds on all platforms, you'll need:

```yaml
# .github/workflows/tauri-build.yml
name: Build Tauri Apps

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        platform: [macos-latest, ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.platform }}

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - uses: dtolnay/rust-toolchain@stable

      - name: Install dependencies (Ubuntu only)
        if: matrix.platform == 'ubuntu-latest'
        run: |
          sudo apt-get update
          sudo apt-get install -y libwebkit2gtk-4.1-dev build-essential curl wget file libssl-dev libayatana-appindicator3-dev librsvg2-dev

      - name: Install Node dependencies
        run: npm ci

      - name: Build Tauri app
        run: npm run tauri:build

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: tauri-app-${{ matrix.platform }}
          path: src-tauri/target/release/bundle/
```

## Configuration Files

- `src-tauri/tauri.conf.json` - Main Tauri configuration
- `src-tauri/Cargo.toml` - Rust dependencies
- `next.config.tauri.js` - Next.js static export configuration for Tauri
- `src-tauri/src/lib.rs` - Rust backend code

## Resources

- [Tauri Documentation](https://tauri.app/)
- [Tauri + Next.js Guide](https://tauri.app/v2/guides/frontend/nextjs)
- [Tauri Command System](https://tauri.app/v2/guides/features/command)
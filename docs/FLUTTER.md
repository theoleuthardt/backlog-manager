# Flutter client

The desktop client in `app/` is the Flutter port of `frontend/` (epic #247). It targets macOS, Windows and Linux; mobile is a follow-up. Design and layout come from [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md).

## Setup

1. Install Flutter **3.47.6** (the version in [`app/.fvmrc`](../app/.fvmrc) and the `environment.flutter` constraint in `app/pubspec.yaml`). Either [follow the official guide](https://docs.flutter.dev/get-started/install), use `brew install --cask flutter` on macOS, or use [FVM](https://fvm.app) (`fvm use` reads `.fvmrc`).
2. Install the toolchain of your platform and check it with `flutter doctor`:
   - **macOS:** full Xcode (not only the Command Line Tools) and CocoaPods (`brew install cocoapods`), then `sudo xcodebuild -runFirstLaunch`.
   - **Windows:** Visual Studio with the "Desktop development with C++" workload.
   - **Linux:** `clang cmake ninja-build pkg-config libgtk-3-dev`.
   - The Android and iOS items in `flutter doctor` can stay red, they are not needed yet.
3. `task app:install` fetches the packages.

## Commands

| Task | What it does |
| --- | --- |
| `task app:dev` | run the app on the host platform |
| `task app:lint` | `flutter analyze` (`flutter_lints` plus the stricter rules in `app/analysis_options.yaml`) |
| `task app:test` | `flutter test` |
| `task app:format` / `task app:format:check` | `dart format` / check only |
| `task app:build` | release build for the host platform |

`task lint`, `task test`, `task check`, `task format` and `task install` include the app.

## Layout

```text
app/
  lib/
    design/     tokens, theme, shell and shared widgets
    api/        client generated from backend/openapi.json
    features/   one folder per screen group
    app.dart    root widget (router and providers)
    main.dart
  test/         mirrors lib/; golden tests are added next to the widgets they cover
```

The empty `design/`, `api/` and `features/` folders hold a `.gitkeep` until the issues that fill them land.

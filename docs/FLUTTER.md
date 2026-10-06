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
4. Start a backend (`task db:up`, then `task backend:dev`). The app does not connect to one yet (sign-in comes with #256); a debug build is meant to talk to `http://localhost:8000` by default, through the server setting of #251.
5. With FVM, run `fvm use` in `app/` and put `app/.fvm/flutter_sdk/bin` first on your `PATH`: the tasks call `flutter` and `dart` from the `PATH`.

## Commands

| Task | What it does |
| --- | --- |
| `task app:dev` | run the app on the host platform |
| `task app:lint` | `flutter analyze` (`flutter_lints` plus the stricter rules in `app/analysis_options.yaml`) |
| `task app:test` | `flutter test` (unit, widget and golden tests) |
| `task app:test:update-goldens` | `flutter test --update-goldens`, re-records the golden images |
| `task app:format` / `task app:format:check` | `dart format` / check only |
| `task app:build` | release build for the host platform |

`task lint`, `task test`, `task check`, `task format` and `task install` include the app.

## API client

`app/lib/api/generated/` is generated from `backend/openapi.json` with [`swagger_parser`](https://pub.dev/packages/swagger_parser) (pure Dart, no Java) into `retrofit` clients and `json_serializable` models, and is **committed**, like the web client's `schema.d.ts`: a backend route change shows up as a diff in the PR and, where a field was removed, as a compile error in the code using it. After changing a backend route run `task backend:openapi` and then `task app:generate-api`.

The hand-written part is `lib/api/api_client.dart` (`createApiDio`: Bearer token from the session, a 401 calls the logout callback) and `lib/api/api_error.dart` (`ApiException.from` turns a failed call into the `detail` message of the backend's error body). The generated models already map the backend's snake_case JSON to camelCase fields.

`lib/api/sse.dart` reads the progress streams of the sync and import endpoints: `openSse(dio, path)` yields typed `SseProgress`, `SseDone` and `SseError` events (ending after the first terminal one, `SseStreamEndedException` if the stream closes without one), and cancelling the subscription closes the connection.

`app/pubspec.yaml` overrides `analyzer` to 13.x because the current `build_runner` does not run against `analyzer` 14.5; drop the override once that is fixed upstream.

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

The still empty folders (`design/`, `features/`) hold a `.gitkeep` until the issues that fill them land.

## Running and debugging

`task app:dev` runs `flutter run` for the host platform (macOS, Windows or Linux) with hot reload: press `r` in the terminal to reload, `R` to restart, `q` to quit. The terminal prints the URL of the Dart DevTools (widget inspector, profiler, logs). VS Code and the JetBrains IDEs with the Flutter plugin start the same app from their run button and attach the debugger; open `app/` as the project folder.

A build for another OS cannot be made on this one (Flutter has no cross-compilation for desktop), so Windows and Linux will be checked by the CI runners of those systems (#282).

## Tests

- Pure logic (sorting, filtering, grouping, themes, ...) is ported from `frontend/src/lib/` with the existing test cases, one Dart file per TypeScript file, under `test/` mirroring `lib/`.
- Widgets get widget tests; reusable components of the UI kit also get golden tests (`matchesGoldenFile`) next to them, for the dark and a light theme.
- Golden images live in `test/**/goldens/` and are committed. After an intended visual change run `task app:test:update-goldens`, look at the changed images in the diff and commit them with the code. Goldens will be recorded on the CI platform (#282); if a golden only differs by anti-aliasing on your machine, do not commit it.
- A test that expresses the desired behaviour is not weakened to make a run green; change the code.

## Building and packaging locally

`task app:build` makes a release build for the host platform: `app/build/macos/Build/Products/Release/backlog_manager.app`, `app/build/windows/x64/runner/Release/` or `app/build/linux/x64/release/bundle/`. `API_URL` sets the default server (`task app:build API_URL=https://api.example.com`); it takes effect once the server setting of #251 is in the app, and nothing connects to a backend before the sign-in work of #256. Installers (dmg, msi, AppImage, deb, ...) come from the packaging issue (#277) and the release workflow.

## Architecture

The app talks to the backend directly over REST with the JWT as a Bearer token, like the web client, and keeps no database of its own.

```text
features/*  ──►  providers (Riverpod)  ──►  lib/api (Dio + generated client)  ──►  backend
   │                                              ▲
   └──►  design/ (tokens, theme, shared widgets)  └── Bearer interceptor, 401 → sign out
```

- **State:** Riverpod. A provider per backend resource (entries, categories, statuses, user, space), `AsyncNotifier`s for things that change, query keys carry the backlog scope (personal or space) like the web client's hooks. Screens read providers and hold only UI state.
- **Routing:** `go_router` with the same route names as the web app; a redirect guards the routes that need a session.
- **API:** `lib/api/generated/` is the committed output of `task app:generate-api`; hand-written code never edits it. The backend's snake_case JSON is mapped to camelCase fields in the generated models, so screens never see the wire format. Errors become `ApiException` with the message to show.
- **Design:** widgets read colours and sizes from the `ShelfTokens` theme extension, never hard-coded values, so a theme change repaints everything.
- **Logic:** anything that is not about widgets (sorting, filtering, validation) is plain Dart in a file of its own with unit tests; screens call it.

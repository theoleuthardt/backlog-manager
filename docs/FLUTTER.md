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

`lib/api/server_url.dart` holds the backend URL logic: `parseServerUrl` (https for any host, http only for loopback, no other protocol), the build-time default (`--dart-define=API_URL=https://api.example.com`, `http://localhost:8000` in debug builds, none in a release build without it), `ServerUrlStore` (remembers the user's choice) and `changeServer` (validates, checks `GET /health`, saves, and calls `onChanged` so the caller signs the user out and clears cached data). The "Change" action on the sign-in screen calls `changeServer` once that screen exists.

`app/pubspec.yaml` overrides `analyzer` to 13.x because the current `build_runner` does not run against `analyzer` 14.5; drop the override once that is fixed upstream.

## Logic ported from the web client

The framework-free logic of `frontend/src/lib/` lives in `app/lib/domain/` with its tests in `app/test/domain/`; every vitest case that applies has a Dart equivalent. Function names and signatures stay recognisable so both implementations can be compared.

| TypeScript (`frontend/src/lib/`) | Dart (`app/lib/domain/`) | Notes |
| --- | --- | --- |
| `sortEntries.ts` | `sort_entries.dart` | `SortOption` is an enum with `.value` (the stored id); `parseSortOption` replaces `isSortOption` |
| `filterEntries.ts` | `filter_entries.dart` | ranges are `(min, max)?` records; `emptyFilters` replaces `EMPTY_FILTERS` |
| `groupEntries.ts` | `group_entries.dart` | |
| `categories.ts` | `categories.dart` | |
| `themes.ts` | `themes.dart` | colours only; `themeCssVariables`, `onAccentColor` and the icon filter have no equivalent, `ShelfTokens` (`lib/design/`) replaces them; `shelfOled` is the added built-in and the default |
| `reviewStars.ts` | - | a single constant (`MAX_REVIEW_STARS = 10`), added where the star control is built |
| `statusStyle.ts` | `status_style.dart` | |
| `entryChanges.ts` | `entry_changes.dart` | `EntryFormChanges.isEmpty` replaces comparing with `{}` |
| `diffFields.ts` | `diff_fields.dart` | |
| `splitList.ts` | `split_list.dart` | |
| `trailer.ts` | `trailer.dart` | |
| `backups.ts` | `backups.dart` | |
| `setupWizard.ts` | `routing/guard.dart` | `guardRedirect` also covers sign-in and the loading state, with the same cases for the wizard |
| `safeUrl.ts` | `safe_url.dart` | |
| `largeBacklog.test.ts` | `test/domain/large_backlog_test.dart` | same 10k entries and 3 s budget |
| `apiUrl.ts` | `lib/api/server_url.dart` | ported in #251 |
| `api/backlog.ts` (`toEntryData`, `toNumber`, ...) | `lib/api/mappers.dart` | the generated models already carry camelCase fields; the mappers turn them into the app models in `domain/models.dart` |
| `utils.ts`, `buttonStyles.ts` | - | CSS class helpers of the web client |
| `api/auth.ts`, `csv.ts`, `games.ts`, `user.ts`, `twoFactor.ts`, `space.ts`, `steam.ts`, `igdbSync.ts`, `backups.ts` | `lib/api/generated/` | replaced by the generated client; the streaming calls use the SSE reader (#250) |
| `pathWithQuery.ts` | - | web routing helper, `go_router` builds locations itself |
| `appUpdate.ts` | - | Tauri updater, replaced by the update issues (#278, #279) |

`compareText` and `compareBase` (`text_order.dart`) stand in for `String.localeCompare`: letters compare without regard to case and accents (so "Ärger" sorts with "A", like the web client's ICU collation), then an unaccented spelling comes before an accented one and the lower-case before the upper-case one. Only Latin letters are folded, other scripts compare by code unit. `stableSorted` replaces the guaranteed stable `Array.prototype.sort`, because `List.sort` is not stable.

Deliberate difference from the TypeScript code: `toNumber` returns null for an empty or padded string where `Number('')` is 0 (the API never sends those).

## Layout

```text
app/
  lib/
    design/     tokens, theme, atmosphere and the shared widgets
    shell/      window shell: title bar, sidebar, status bar, shortcuts
    routing/    router, route table, session guard, navigation history
    api/        client generated from backend/openapi.json
    features/   one folder per screen group (so far the debug gallery)
    domain/     pure logic and models, ported from frontend/src/lib/
    app.dart    root widget (router and providers)
    main.dart
  test/         mirrors lib/; golden tests are added next to the widgets they cover
```

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

## Theme and design tokens

`lib/design/` turns the six colours of a theme into the whole Shelf palette. `ShelfTokens.forTheme(resolvedTheme)` returns the hand-tuned token set of a built-in theme that has one (`shelfOled`, `light`, `colorful`, `freaky`; `builtin_tokens.dart`, taken from `docs/design/canvas/shelf.css`) and derives the set of every other theme, including `dark` and custom themes, with `ShelfTokens.fromColors` and the formulas of `docs/DESIGN_SYSTEM.md`. `buildShelfTheme(tokens)` creates the `ThemeData` with the tokens and `ShelfTextStyles` as extensions, so widgets use `Theme.of(context).extension<ShelfTokens>()!`.

- The font is Plus Jakarta Sans, bundled in `app/assets/fonts/` (five static weights, SIL Open Font License, `OFL.txt`), so the app looks the same offline.
- Text colours (`foreground`, `text2`, `muted`, `faint`) reach 4.5:1 on the background in every built-in theme and the status colours reach it on the surface; tests in `test/design/` pin that. The light theme's `danger` on its cream background is 4.27:1, just below, which is why the status colours are checked against the surface they are used on.
- The derived colours of a custom theme follow the written formulas, the built-ins use their tuned values; the test compares both with the documented Shelf OLED table.

## Window shell and routing

`lib/shell/` is the frame of the main window: `AppShell` puts the title bar, the sidebar, the main pane with an inspector slot and the status bar over the atmosphere. Pages come from `go_router` (`lib/routing/router.dart`):

| Route | Window |
| --- | --- |
| `/` Home, `/library`, `/steam`, `/import`, `/export`, `/creation-tool`, `/appearance`, `/space` | main window with the sidebar (`ShellRoute`) |
| `/settings`, `/sign-in`, `/setup`, `/loading` | full-window pages: the same title bar and atmosphere, no sidebar |

- **Route guard** (`routing/guard.dart`, `guardRedirect`): while the session is checked everything shows `/loading`, signed-out users go to `/sign-in`, users with an unfinished setup are funnelled into `/setup`, finished users are sent from sign-in, the wizard and the loading page to `/`. It replaces the web client's `setupRedirect`. The app opens at sign-in. The session itself (`routing/session.dart`) is only state until the sign-in feature fills it.
- **Secondary windows:** Settings, the wizard and sign-in are full-window routes with the same chrome, not second native windows. A second window needs a second Flutter engine per window (`desktop_multi_window`), which is not worth it before these screens exist; the decision can be revisited with the settings window issue.
- **Platform chrome:** `window_manager` hides the native title bar (`main.dart`). macOS keeps its traffic lights at the left of the title bar; Windows and Linux get minimise, maximise and close buttons on the right. The title bar is the drag region and a double click maximises. `WindowControls` is the seam the tests replace.
- **Back and forward** (`routing/history.dart`) keep their own history of visited pages, because `go_router` cannot walk one.
- **Shortcuts** (`shell/shell_shortcuts.dart`): `/` focuses the search field (not while typing), Cmd+K (macOS) or Ctrl+K opens the command palette flag (`paletteOpenProvider`, the palette itself is a later issue) and Esc closes the palette and then the inspector. Esc uses its own intent because the framework's `DismissIntent` is answered by other widgets first.
- **Screens fill the shell** through providers: `shellStatusProvider` (counts and sync state in the status bar), `shellInspectorProvider` (the inspector slot), `navigationCountsProvider` (numbers next to sidebar items) and `addGameRequestProvider` ("Add game" in the sidebar).
- The account row's menu switches the theme (`themeIdProvider`, not stored yet, that is the appearance issue) and logs out.

## UI kit

`lib/design/widgets/` holds the components of the design catalogue; every one reads its colours from `ShelfTokens` and its text from `ShelfTextStyles`. A debug build has them all on one page at `/gallery` (`features/gallery/`, not registered in release builds).

| File | Components |
| --- | --- |
| `pressable.dart` | `ShelfPressable`: hover, press, 2 px accent focus ring with 2 px offset, Enter and Space, pointer cursor, button semantics; the base of everything clickable |
| `buttons.dart` | `ShelfButton` (primary, secondary, quiet, danger, with icon, disabled at 40%), `ShelfIconButton` |
| `chips.dart` | `ShelfChip` (neutral, active, accent, info, ok, add with a dashed border; clickable, removable) |
| `segmented.dart`, `tabs.dart` | `ShelfSegmented`, `ShelfTabs` |
| `fields.dart`, `select.dart` | `ShelfField`, `ShelfFormGroup` with `ShelfFormRow`, `ShelfSelect` |
| `toggles.dart`, `progress.dart` | `ShelfSwitch`, `ShelfCheckbox` (mixed state), `ShelfProgressBar`, `InterestSegments`, `StarRating` |
| `cover.dart` | `ShelfCover` (2:3, title fallback in a colour from the title, progress, meta, selected ring, check circle), `ShelfCoverGrid`, `ShelfRow`, `proxiedImageUrl` |
| `table.dart` | `ShelfDataTable` (header, rows, hover, selected, checkbox column), `ShelfListRow` |
| `menu.dart` | `ShelfMenuAnchor`, `ContextMenuRegion` (right click), `ShelfPopover`; items with icon, shortcut hint, check, danger, submenus and dividers on top of `MenuAnchor` |
| `sheet.dart`, `toast.dart`, `stepper.dart` | `ShelfSheet` with `ShelfSheetFooter` and `showShelfSheet`, `ShelfToast` with `showShelfToast`, `ShelfStepper` |

- **Covers and images:** `ShelfCover` takes an `ImageProvider`; the screens build it from `proxiedImageUrl(serverUrl, imageLink)` with `CachedNetworkImageProvider` (memory and disk cache), so the app only talks to the image proxy of its own server. A picture that fails to load falls back to the title.
- **Menus:** `MenuAnchor` closes on Esc only while the focus is inside it, so a menu opened with the mouse closes with a click outside.
- **Goldens:** each component group has goldens in Shelf OLED and light under `test/design/widgets/goldens/`. The test renderer draws text in a block font and shadows as hard shapes, which keeps the images identical on every platform; they show layout, colour and state, not typography. Re-record with `task app:test:update-goldens` after an intended change and look at the images.

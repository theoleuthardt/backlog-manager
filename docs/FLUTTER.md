# Flutter client

The desktop client in `app/` is the Flutter port of `frontend/` (epic #247). It targets macOS, Windows and Linux; mobile is a follow-up. Design and layout come from [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md).

## Setup

1. Install Flutter **3.47.6** (the version in [`app/.fvmrc`](../app/.fvmrc) and the `environment.flutter` constraint in `app/pubspec.yaml`). Either [follow the official guide](https://docs.flutter.dev/get-started/install), use `brew install --cask flutter` on macOS, or use [FVM](https://fvm.app) (`fvm use` reads `.fvmrc`).
2. Install the toolchain of your platform and check it with `flutter doctor`:
   - **macOS:** full Xcode (not only the Command Line Tools) and CocoaPods (`brew install cocoapods`), then `sudo xcodebuild -runFirstLaunch`.
   - **Windows:** Visual Studio with the "Desktop development with C++" workload.
   - **Linux:** `clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev`; the token store (`flutter_secure_storage`) needs a Secret Service such as gnome-keyring at runtime.
   - The Android and iOS items in `flutter doctor` can stay red, they are not needed yet.
3. `task app:install` fetches the packages.
4. Start a backend (`task db:up`, then `task backend:dev`). A debug build talks to `http://localhost:8000` by default; the sign-in screen can change the server (`lib/api/server_url.dart`).
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

`lib/api/server_url.dart` holds the backend URL logic: `parseServerUrl` (https for any host, http only for loopback, no other protocol), the build-time default (`--dart-define=API_URL=https://api.example.com`, `http://localhost:8000` in debug builds, none in a release build without it), `ServerUrlStore` (remembers the user's choice) and `changeServer` (validates, checks `GET /health`, saves, and calls `onChanged` so the caller signs the user out and clears cached data). The "Change" action on the sign-in screen calls `changeServer`.

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
    auth/       token store, auth API, sign-in state machine
    platform/   native hooks such as opening a URL
    api/        client generated from backend/openapi.json
    features/   one folder per screen group (auth, setup and the debug gallery)
    domain/     pure logic and models, ported from frontend/src/lib/
    app.dart    root widget (router and providers)
    main.dart
  test/         mirrors lib/; golden tests are added next to the widgets they cover
```

## Checks on pull requests

`.github/workflows/app.yml` runs when `app/` or `backend/openapi.json` changes: formatting, `flutter analyze`, a check that `lib/api/generated/` matches `backend/openapi.json` (the commands of `task app:generate-api`, then `git diff --exit-code`), all tests without the goldens, and a Linux release build. The golden tests run in a job of their own that uploads the diff images of a failure as the `golden-failures` artifact. The golden images are recorded on Linux, the platform of the CI runner; on macOS or Windows the text edges differ by a few pixels, so run `flutter test --exclude-tags golden` there and re-record with `task app:test:update-goldens` on Linux (or take the images from the `golden-failures` artifact).

If `flutter test` hangs or prints "The Dart compiler exited unexpectedly" on a small machine, run it with `--concurrency=2`: several test files compiling at once can crash the compiler.

## Running and debugging

`task app:dev` runs `flutter run` for the host platform (macOS, Windows or Linux) with hot reload: press `r` in the terminal to reload, `R` to restart, `q` to quit. The terminal prints the URL of the Dart DevTools (widget inspector, profiler, logs). VS Code and the JetBrains IDEs with the Flutter plugin start the same app from their run button and attach the debugger; open `app/` as the project folder.

A build for another OS cannot be made on this one (Flutter has no cross-compilation for desktop), so Windows and Linux will be checked by the CI runners of those systems (#282).

## Tests

- Pure logic (sorting, filtering, grouping, themes, ...) is ported from `frontend/src/lib/` with the existing test cases, one Dart file per TypeScript file, under `test/` mirroring `lib/`.
- Widgets get widget tests; reusable components of the UI kit also get golden tests (`matchesGoldenFile`) next to them, for the dark and a light theme.
- Golden images live in `test/**/goldens/` and are committed. After an intended visual change run `task app:test:update-goldens`, look at the changed images in the diff and commit them with the code. Golden tests carry the tag `golden` (`dart_test.yaml`), so `flutter test --exclude-tags golden` skips them and `flutter test --tags golden` runs only them. Golden images are recorded on Linux (see "Checks on pull requests"); do not commit images recorded on another platform.
- A test that expresses the desired behaviour is not weakened to make a run green; change the code.

## Building and packaging locally

`task app:build` makes a release build for the host platform: `app/build/macos/Build/Products/Release/backlog_manager.app`, `app/build/windows/x64/runner/Release/` or `app/build/linux/x64/release/bundle/`. `API_URL` sets the default server (`task app:build API_URL=https://api.example.com`) and the user can change it on the sign-in screen. Installers (dmg, msi, AppImage, deb, ...) come from the packaging issue (#277) and the release workflow.

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

- **Route guard** (`routing/guard.dart`, `guardRedirect`): while the session is checked everything shows `/loading`, signed-out users go to `/sign-in`, users with an unfinished setup are funnelled into `/setup`, finished users are sent from sign-in, the wizard and the loading page to `/`. It replaces the web client's `setupRedirect`. The app opens at sign-in. The session itself (`routing/session.dart`) is state that `AuthController` fills.
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

## Sign-in and session

`lib/auth/` holds the session of the app, `features/auth/` its two pages.

- **Token:** `TokenStore` keeps the access token in the OS secure store (`flutter_secure_storage`: Keychain, Credential Manager, libsecret). On macOS the legacy keychain is used because the data protection keychain needs a signed app with a keychain access group, which comes with the signing issue (#280).
- **State machine:** `AuthController` (`auth_controller.dart`) restores the session at start (`restore`, called from `main.dart`), signs in with a password and, for an account with two-factor, with a 6-digit or backup code (whitespace is removed), signs out and ends an expired session. `LoginFlow` is what the sign-in page shows (step, challenge, busy, error banner); the session itself stays in `SessionNotifier`, which the route guard reads.
- **Revocation and stale answers:** a 401 from any request calls `sessionExpired` (the Dio interceptor of `createApiDio`), which signs out and shows "Your session has ended". Every request remembers the `sessionGenerationProvider` value it started in and is dropped when the user signed out in the meantime, so a slow answer cannot bring the old session back. The generation grows on every sign-in and sign-out; providers that hold the data of a user have to watch it, so nothing of the previous user survives into the next session.
- **Server:** the sign-in page shows the server in use and "Change" opens a sheet that validates the address, asks `GET /health` and signs the user out when the server really changed (`changeServer` of `api/server_url.dart`); `apiDioProvider` is created again for the new server.
- **Not ported on purpose:** the web client's "already signed in" state with "Go to Dashboard" and "Sign out": the route guard sends a signed-in user from sign-in to Home, so that state cannot occur.

## Setup wizard and partial updates

`features/setup/` is the first-run wizard: theme, sorting, Steam, IGDB, done, with a vertical stepper. Every step saves its values when the user presses Next (`SetupController`), a failed save stays on the step with a toast, "Skip setup" and the last step set `setup_completed` and refresh the session user, which makes the route guard lead to Home. A single IGDB field is refused with the message of the web client; the theme applies at once and is saved with the first step.

- **Partial updates:** `PUT /api/user/me` reads an explicit `null` as "clear this field" and leaves omitted fields alone. The generated request classes send every field, nulls included, so one saved setting would wipe the others. Use `UserUpdate` (`auth/user_api.dart`), which only sends the fields that are set, for every partial update of the user, and do the same for the entry updates (`PUT /api/backlog/entries/{id}`). Clearing a field will need an explicit way to send a `null`, to be added with the first screen that needs it (the settings).
- **Links:** `LinkText` writes links inside a paragraph; `urlOpenerProvider` opens them in the system browser and is replaced in tests.

## Entries and Home

`data/backlog_api.dart` wraps the backlog routes (`BacklogApi`, faked in tests) and `data/backlog_providers.dart` holds the state: `entriesProvider(spaceId)` is an `AsyncNotifier` per backlog scope (null is the personal one), dropped when the session generation changes. `moveToStatus` changes the list at once, restores only that entry when the request fails and returns the error message, so the caller decides how to show it. Partial updates go through the map-based `EntryUpdate`.

`features/home/` is the Home screen: four stat tiles, the "Continue playing" hero card (the game in progress with the most playtime, achievements still locked for Steam games, "Open details" and "Mark as completed"), and the shelves "Up next" and "Recently completed" with "See all". The "See all" and cover links open `/library?status=...` and `/library?entry=...`; the library screen reads these parameters. The Home screen reports the number of games to the status bar.

## Library

`features/library/` is the library screen. `domain/library_groups.dart` builds the sections for every sort option (status groups include empty ones and the custom statuses, category groups append categories without games, a status filter limits the status groups); `library_content.dart` feeds it from the entries and watches only the sort option and its direction, so folding a group or paging does not sort again; `library_view.dart` holds the view state (sort, layout, collapsed groups per sort and group, 60-cover pages). The page is one `CustomScrollView` with a header sliver and a grid or list sliver per group, so a library of thousands of games only builds what is on screen. The account's default sort and whether a Steam ID is set come with the session user (`auth/session_user_mapper.dart`).

The IGDB and Steam sync buttons of the toolbar arrive with their features (#268, #269), the filter bar with #261, the selection mode with #262 and drag and drop with #263; collapsed groups are kept in memory for the session.

### Filter bar

The 44 px bar under the library toolbar (`features/library/filter_bar.dart`) holds one token per active filter, the dashed "+ Add filter" token, and on the right the owned-only switch, "Reset", the sort menu with its direction button and the grid or list toggle. The filters live in `data/filter_providers.dart` (`filtersProvider`: the search text of the title bar plus the filters; it survives screen changes and starts empty with the next session); `effectiveFiltersProvider` drops selected categories that no longer exist, and `filterOptionsProvider` and `filterBoundsProvider` supply the picker values (the largest value of the data rounded up, at least 10 hours, for the time ranges). The pure part is in `domain/filter_tokens.dart` (`FilterField`, `filterTokens`, `setListFilter`, `setRangeFilter`, `resetFilters`, `filterBounds`) on top of the ported `filterEntries`.

- "+ Add filter" opens a searchable list of the fields (Category only when categories exist) and then the picker of the chosen field; a click on the text of a token opens the same picker, the x removes the filter.
- A list field is a list of checks; a range has a minimum and a maximum (fields and slider). A range over the whole slider is no filter, and entries without a value are not excluded by a range.
- The title bar search filters by title, ignoring case, and does not count as a filter. The status bar shows "N of M games" and, when filters are active, the number of filters; each list filter, each range and owned only count once.


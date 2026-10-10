# Parity matrix: web and Tauri client against the Flutter client

Built from `frontend/src/app/`, `frontend/src/hooks/` and `frontend/src/lib/` for issue #286. The old client is removed at the cutover (#287), so every row must be done or dropped on purpose before that. Status: **done** (in `app/`), **new** (only in the Flutter client), **open** (an issue exists), **dropped** (on purpose, with the reason). Where the Flutter code lives is listed in `docs/FLUTTER.md`.

## Pages

| Old | Flutter | Status |
| --- | --- | --- |
| `login` | `features/auth/sign_in_page.dart`: password, two-factor code or backup code, server address | done |
| `setup` | `features/setup/`: the wizard (profile, Steam, API keys, theme) | done |
| `dashboard` | `features/library/`: groups, covers and rows, filters, sort, drag and drop, selection, context menu | done |
| (none) | `features/home/`: the home screen with Up next, short games first, recently completed and the stats of the backlog | new |
| `account` | `features/settings/`: general, integrations, security (two-factor), backups, about | done |
| `creation-tool` | `features/creation/` and `features/add_game/`: search, wrong game, cover, duplicate check, creation tool | done |
| `import-csv` | `features/import_csv/` | done |
| `export-csv` | `features/export/` | done |
| `steam` | `features/steam/` | done |
| `space` | `features/space/` | done |
| `themes` | `features/appearance/` | done |
| landing page (`app/page.tsx`, `Features`, `HeroCta`, `ScrollSection`) | none | dropped: the app is not a hosted website after the cutover (#287) |

## Components and dialogs

| Old | Flutter | Status |
| --- | --- | --- |
| `AccountContent` | `features/settings/*_tab.dart` | done |
| `AchievementProgress` | `features/achievements/` | done |
| `AppUpdateSection`, `AppUpdater`, `lib/appUpdate` | none yet | open: #278, #279 |
| `AuthCard`, `RequireAuth` | `features/auth/`, `routing/guard.dart` | done |
| `BacklogEntry`, `EntryTile`, `EntryDetail` | library tiles and `features/inspector/` (autosave, tabs, trailer, stats) | done |
| `BackupSection` | `features/settings/backups_tab.dart` | done |
| `BottomSheet`, `useMediaQuery` (phone layouts) | none | dropped for the desktop client: phones are #289 |
| `BulkActionBar` | `features/library/selection_bar.dart` | done |
| `CategoryGroupSection`, `GroupSection`, `StatusGroupSection` | `LibraryGroup` sections of `library_page.dart` | done |
| `CategoryManager`, `CategoryPicker` | `features/common/category_*.dart` | done |
| `CoverPickerDialog`, `WrongGameDialog` | `features/add_game/cover_picker_sheet.dart`, `wrong_game_sheet.dart` | done |
| `CreationToolForm`, `EntryCreationDialog` | `features/creation/`, `features/add_game/` | done |
| `DashboardContent`, `DashboardSidebar` (filters) | `features/library/`, `filter_bar.dart` | done |
| `DashboardSearch`, `SearchBar` | the search field of the title bar, "/" focuses it | done |
| `DragPreview`, `DraggableEntry` | `features/library/entry_drag.dart` | done |
| `ExportCSVButton`, `ExportCSVContent`, `ImportCSVButton`, `ImportCSVContent` | `features/export/`, `features/import_csv/` | done |
| `ExternalAnchor`, `lib/externalLink` | `platform/url_opener.dart` | done |
| `FieldDiffList`, `lib/diffFields` | `features/creation/field_diff_list.dart`, `domain/diff_fields.dart` | done |
| `Footer` | the status bar of the shell | done |
| `FreakyBackground` | `design/freaky_orbs.dart` | done (#340) |
| `UniverseBackground`, `lib/starfield` | `design/atmosphere.dart` | done |
| `GameImage` | cover widgets with the image proxy (`data/entry_image.dart`) | done |
| `GamePriceSection` | `features/prices/` | done |
| `IgdbSyncButton` | `features/igdb_sync/` | done |
| `Navbar`, `SpaceNavLink` | `shell/sidebar.dart`, `shell/title_bar.dart` (the space entry has the invitation dot) | done |
| `SetupWizard` | `features/setup/` | done |
| `ShareToSpaceButton` | `features/space/share_to_space_button.dart` | done |
| `SpacePage` | `features/space/` | done |
| `StatusSelect` | `features/common/status_select.dart` | done |
| `SteamContent`, `SteamSyncButton` | `features/steam/` | done |
| `ThemeCreator`, `ThemeMenu`, `ThemeContext` | `features/appearance/`, the account row of the sidebar, the palette | done |
| `TrailerDialog`, `lib/trailer` | the trailer tab opens the browser, `domain/trailer.dart` | open: #325 (in-app player) |
| `WishlistSyncDialog`, `lib/wishlistSyncReport` | `features/library/wishlist_sync_prompt.dart` | done |
| (none) | command palette (Cmd/Ctrl+K), keyboard shortcuts, the debug gallery of the UI kit | new |

## Logic of `frontend/src/lib/` (each had a vitest file)

| Old | Flutter | Status |
| --- | --- | --- |
| `sortEntries`, `filterEntries`, `groupEntries`, `categories`, `statusStyle`, `reviewStars`, `splitList`, `entryChanges`, `safeUrl`, `themes`, `setupWizard`, `backups`, `steamWishlist`, `wishlistSyncReport`, `trailer` | the same names in `app/lib/domain/` with the cases of the old tests ported | done |
| `largeBacklog.test.ts` (a very large backlog stays fast) | the CSV preview test with a thousand rows; no test for 2000 library entries yet | open: add one, see the edge cases below |
| `apiUrl`, `pathWithQuery` | `api/server_url.dart`, `go_router` | done |

## Behaviour and edge cases to compare in the beta

| Case | Flutter | Status |
| --- | --- | --- |
| Empty backlog | "Your backlog is empty" with an add button; the shared space has its own empty text | done |
| 2000 entries | lazy slivers in the library; not measured | open: #283 compares it with the Tauri baseline |
| Expired token | a 401 ends the session with "Your session has ended. Sign in again." | done |
| Backend offline | "Try again" on the library and the space, error toasts and write-only fields elsewhere; a failed refresh of the space keeps the screen | done |
| Large CSV | files up to 10 MB, a thousand rows stay fast, preview and import can be cancelled | done |
| Space with an invitation | accept, decline, the dot in the sidebar, the 30 second refresh | done |
| Two-factor sign-in, enrolment and disabling | `auth/`, `features/settings/security_tab.dart` | done |
| Wishlist import for the first time only, skipped games, automatic sync report | `features/steam/`, `wishlist_sync_prompt.dart` | done |
| Theme from the web client shows up in the app and the other way round | the same `custom_themes` shape and cache key | done (check in the beta) |
| Window chrome, update from GitHub Releases, signing | title bar done; updates #278, #279; signing #280; release workflow #281 | open |

## Sign-off

- [ ] Every row above is done or dropped on purpose
- [ ] The beta of the Flutter client ran next to the Tauri app for two weeks without a blocking bug (the beta needs the packaging, #277, and the release workflow, #281)
- [ ] Every gap found in the beta is an issue and is closed

# Shelf design system

"Shelf" is the redesign direction for Backlog Manager: cinematic and cover-first, like a console home screen. Games are the content, the chrome stays quiet, and one accent colour carries focus and progress.

This document is the spec a second client (the planned Flutter client, issue #240) is built from. It does not depend on the web frontend's code. Related files:

- [`design/shelf.tokens.json`](design/shelf.tokens.json): every token below in machine-readable form
- [`design/shelf.css`](design/shelf.css): the stylesheet the design canvas was drawn with, as a visual reference for spacing, radii and states
- The design canvas with every page drawn (private to the owner): <https://claude.ai/artifact/GNWoHDeo9QcksZDmpK8nGd>
- [`DASHBOARD_UX.md`](DASHBOARD_UX.md): behaviour decisions of the dashboard that the new layout keeps

## Principles

1. **Covers first.** The cover art is the largest thing on every screen. Text sits on it or directly beneath it.
2. **One accent.** A single accent colour marks the primary action, progress, selection and focus. Everything else is neutral.
3. **Shelves, not tables.** Lists of games are grids or horizontal shelves of covers; dense rows only for imports and search results.
4. **Quiet chrome.** Panels are soft filled surfaces without borders; borders appear only on inputs, dashed "add" chips and focus.
5. **Changes save themselves.** Entry edits autosave; there is no Update button. Destructive actions ask first.
6. **Themeable from six colours.** Users keep the six-colour theme model; every other colour is derived (see below).

## Theme model and tokens

### Six input colours

A theme is six hex colours, unchanged from the current app (`frontend/src/lib/themes.ts`): `background`, `surface`, `foreground`, `accent`, `border`, `glow`.

| Role | Used for |
|---|---|
| `background` | Page background, text on `accent` buttons |
| `surface` | Panels, dialogs, inputs' surroundings |
| `foreground` | Primary text, active pill, icons |
| `accent` | Primary buttons, progress, selection ring, focus ring, active tab underline |
| `border` | Strong outlines: secondary button border, dashed "add" chips, input focus |
| `glow` | Hero tint and hover/focus glow; defaults to `accent` |

### Derived colours

Computed from the six inputs, so a custom theme automatically gets a complete palette:

| Token | Formula | Shelf Dark value |
|---|---|---|
| `surface2` | mix(`surface`, `foreground`, 3%) | `#1b1c22` |
| `surface3` | mix(`surface`, `foreground`, 6%) | `#23252c` |
| `borderSubtle` | `surface3` | `#23252c` |
| `text2` | mix(`foreground`, `background`, 11%) | `#d9d9dd` |
| `muted` | mix(`foreground`, `background`, 35%) | `#a3a5ad` |
| `faint` | mix(`foreground`, `background`, 60%) | `#6a6c75` |
| `accentSoft` | `accent` at 14% opacity | amber at 14% |
| `onAccent` | black or white, whichever has the higher contrast against `accent` | `#1a1103` |

Semantic colours do not change with the theme (they are adjusted for contrast on light backgrounds): success `#34d399`, danger `#ff6b81`, info `#60a5fa`.

### Built-in themes

The four built-in themes keep their ids and colours. **Shelf Dark** is new and becomes the default; the former default `dark` (black with a blue accent) stays selectable.

| Theme | background | surface | foreground | accent | border | glow |
|---|---|---|---|---|---|---|
| `shelfDark` (new default) | `#0e0f12` | `#15161b` | `#f2f2f3` | `#f5a524` | `#3a3c45` | `#f5a524` |
| `dark` | `#000000` | `#0f0f12` | `#ffffff` | `#2563eb` | `#ffffff` | `#3b82f6` |
| `light` | `#f5f4ef` | `#ffffff` | `#15151b` | `#4f46e5` | `#15151b` | `#818cf8` |
| `colorful` | `#0b0720` | `#1a1240` | `#fdf2ff` | `#ff3ea5` | `#7c4dff` | `#22d3ee` |
| `freaky` | `#04040e` | `#0e0e26` | `#eaffe9` | `#a3ff12` | `#00ffd0` | `#ff00e5` |

Open point: on the old themes `border` is a bright colour (white, indigo, cyan). Shelf uses it only for strong outlines, so those themes look calmer than before. Whether to soften them is a design decision for the Flutter port.

### Typography

Font: **Plus Jakarta Sans** (weights 400 to 800). Sizes in logical pixels.

| Style | Size / line height | Weight | Tracking | Use |
|---|---|---|---|---|
| `display` | 64 / 1.0 | 800 | -0.03em | Landing headline, hero title |
| `page` | 40 / 1.05 | 800 | -0.03em | Page title |
| `section` | 22 / 1.2 | 800 | -0.01em | Shelf and group headings |
| `panelTitle` | 18 / 1.2 | 800 | -0.01em | Panel headings |
| `lead` | 17 / 1.6 | 400 | 0 | Descriptions, intros (max 62 characters wide) |
| `body` | 15 / 1.45 | 400 | 0 | Default text |
| `label` | 13 / 1.3 | 600 | 0 | Field labels, captions in muted colour |
| `eyebrow` | 13 / 1.2 | 700 | 0.14em | Uppercase kicker above titles, accent colour |
| `coverTitle` | 18 / 1.1 | 800 | 0 | Title printed on a cover without art |

### Spacing, radii, elevation, motion

- **Spacing scale:** 4, 8, 12, 16, 20, 24, 28, 32, 48, 56. Page side padding is 56. Touch targets are at least 44.
- **Radii:** field 12, card 16, panel 22, dialog 24, hero 28, pill 999.
- **Elevation:** only floating layers cast a shadow (menu, dialog, bulk bar, toast, focused cover); panels are flat.
- **Motion:** 150 ms for hover and press, 250 ms for panels and menus, 350 ms for the page slide-in (12 px). Everything uses ease-out. With reduced motion enabled there is no slide and no scale.
- **Focus and selection:** a 3 px accent outline with a 3 px offset. A focused control and a selected cover look the same on purpose.

## Components

Each component lists its parts and states. The "Flutter" column is a suggestion, not a requirement.

| Component | Anatomy and states | Flutter |
|---|---|---|
| **Top bar** | Logo, nav pills, search field, avatar. Active pill is filled with `foreground` and `background` text. Search focuses on `/` or Ctrl/Cmd+K | custom `AppBar`-like row; `CallbackShortcuts` |
| **Button** | Pill, 44 high (36 small). Primary (accent fill, `onAccent` text), secondary (strong border), ghost, danger (danger text), icon (42 square). States: hover lightens, focus ring, disabled 40% | `FilledButton`/`OutlinedButton` themed through `ShelfTheme` |
| **Chip** | Pill. Neutral (`surface2`), active (`foreground` fill), accent (`accentSoft` fill, accent text), add (dashed border) | `Chip` / `ActionChip` |
| **Segmented control** | Pill track on `surface`, selected segment filled with `foreground` | `SegmentedButton` themed |
| **Tabs** | Text tabs, active one bold with a 3 px accent underline | `TabBar` with custom indicator |
| **Field** | Label above (13 muted), 46 high input on `surface2` with `borderSubtle`, radius 12, hint below in `faint`; textarea 110 high | `TextField` + `InputDecorationTheme` |
| **Switch** | 44x26 pill, on = accent track with `onAccent` knob | `Switch` themed |
| **Cover** | 2:3, radius 16. Title printed bottom-left when there is no art. Optional progress bar and meta line beneath. Selected: accent outline; selection mode adds a 26 px check circle top left | `AspectRatio` + `ClipRRect` + `CachedNetworkImage` |
| **Cover grid** | Auto-fill columns of at least 168, gap 28 / 20. Groups of 60 with a "show more" button | `SliverGrid` with `SliverGridDelegateWithMaxCrossAxisExtent` |
| **Shelf row** | Horizontal row of 168-wide covers that fades out at the edge | `ListView.builder(scrollDirection: Axis.horizontal)` |
| **Hero** | Large rounded banner with a tinted backdrop, eyebrow, display title, progress and two buttons | custom `Stack` |
| **Progress** | 6 high track on `surface3`, accent fill; thin 3 to 4 variant under covers; segmented 10-step variant for "interest" | `LinearProgressIndicator` themed; custom segments |
| **Panel** | `surface` fill, radius 22, padding 24, title + description + content, no border | `Card` with zero elevation |
| **Dialog** | `surface`, radius 24, padding 28, max width 560 to 720, scrim `rgba(5,5,7,0.72)` | `Dialog` |
| **List row** | 12/16 padding, radius 14, thumbnail 44 wide (2:3), title, meta in muted, trailing chip or button; hover lifts to `surface2` | `ListTile`-like row |
| **Context menu** | `surface2`, radius 14, 6 padding, items 9/12 with optional submenu arrow, separators, danger item last | `MenuAnchor` / `ContextMenuRegion` |
| **Bulk bar** | Floating pill bar pinned at the top of the content column: count, select all, clear, status menu, delete, done | sticky `SliverPersistentHeader` |
| **Toast** | `surface2`, radius 14, optional action ("Undo") | `ScaffoldMessenger` snackbar themed |
| **Stepper** | Numbered circles joined by lines; done = success with a check, current = accent, upcoming = `surface3` | custom |

## Interaction patterns

- **Open an entry:** clicking a cover opens the entry as a dialog above the library. The dashboard owns this one dialog, so an entry that moves to another group (a category or status change) does not close it.
- **Autosave:** edits in the entry dialog save about 800 ms after the last change; the footer shows "Saving..." then "All changes saved". A failed save shows "Not saved" and a toast; changes still pending on close are saved.
- **Selection mode:** the "Select" button, or "Select" in the context menu, turns covers into checkable cards and shows the bulk bar. Bulk actions: set status, delete (always confirmed). Covers keep their position while selected.
- **Context menu (right click):** open details, select, move to status (submenu), categories (checkable submenu that stays open), delete.
- **Drag and drop:** in the status sort a cover can be dragged onto another status group; in the category sort onto a category group (adds it and removes the first one). Empty groups stay visible as drop targets. A toast offers "Undo" for a status change.
- **Search more:** the "wrong game" dialog shows a "Can't find your game? Search more" button that repeats the search with the deep mode (other spellings, bundles).
- **Long operations** (Steam and IGDB sync, CSV import) show a progress bar fed by the server's progress events; the dialog cannot be closed while it runs.
- **Keyboard:** `/` or Ctrl/Cmd+K focuses the search; every control is reachable by Tab and shows the focus ring.

## Screens

Routes are the current web routes; the Flutter client can use the same names. Every screen talks to the backend through the OpenAPI client (`backend/openapi.json`).

| Screen | Route | Purpose | Main components | API |
|---|---|---|---|---|
| Landing | `/` | Introduce the app, link to login | Top bar, hero, feature panels | none |
| Login | `/login` | Email and password, then the two-factor code | Dialog-like panels, fields | `POST /api/auth/login`, `POST /api/auth/2fa/login-verify` |
| Setup wizard | `/setup` | First-run: theme, default sort, Steam, IGDB, done | Stepper, panel, fields | `PUT /api/user/me` |
| Home / dashboard | `/dashboard` | Continue playing hero plus shelves | Hero, shelf rows | `GET /api/backlog/entries` |
| Library | `/dashboard` (grouped view) | All games grouped by status or category, filters, selection | Cover grid, filter panel, bulk bar, context menu, dnd | `GET/PUT/DELETE /api/backlog/entries*`, `/categories*`, `/statuses*`, `POST /api/igdb-sync/stream`, `POST /api/user/steam/sync/stream` |
| Entry details | dialog in the library | Cover, status, categories, times, review, trailer, delete | Hero banner, tabs, beat-time panel, switch | `PUT/DELETE /api/backlog/entries/{id}`, `GET /api/user/steam/achievements`, `GET /api/games/{steam_app_id}/price`, `GET /api/games/key-shop-prices` |
| Add a game | dialog | Search IGDB, continue in the creation tool | Dialog, list rows | `GET /api/games/enriched-search`, `GET /api/games/steam-app-id` |
| Wrong game | dialog | Replace the matched game, "search more" | Dialog, list rows | `GET /api/games/enriched-search?deep=true` |
| Cover picker | dialog | Pick another cover | Dialog, cover grid | `GET /api/games/steamgriddb-covers*`, `GET /api/games/steamgriddb-search` |
| Creation tool | `/creation-tool` | Create an entry with all fields, personal or shared | Panels, fields, switch, segmented control | `POST /api/backlog/entries`, `GET /api/backlog/entries/duplicates` |
| Steam sync | `/steam` | Preview and import library and wishlist | Panels, list rows, progress | `POST /api/user/steam/library/preview/stream`, `.../import/stream`, `GET .../wishlist/preview`, `POST .../wishlist/import/stream` |
| CSV import | `/import-csv` | Map columns, preview, import | Panel with selects, list rows with status chips | `POST /api/csv/headers`, `/preview/stream`, `/submit/stream` |
| CSV export | `/export-csv` | Download the backlog as CSV | Panel, button | `GET /api/backlog/entries` (client-side CSV) |
| Account | `/account` | Default sort, two-factor, Steam, IGDB/SteamGridDB keys, Discord alerts, backups, app updates | Section nav, panels, list rows | `GET/PUT/DELETE /api/user/me`, `/api/auth/2fa/*`, `/api/backups*` |
| Theme creator | `/themes` | Built-in and custom themes with live preview | Theme cards, colour fields, preview panel | `PUT /api/user/me` |
| Shared space | `/space` | Two-person shared backlog, invitations | Member header, invitation panel, cover grid with per-member progress | `GET /api/space`, `POST /api/space/invitations*`, `DELETE /api/space/membership` |

## Flutter mapping

### Theme

Keep the six-colour model as the source and expose the derived tokens through a `ThemeExtension`, so widgets read `Theme.of(context).extension<ShelfTokens>()` instead of hard-coding colours.

```dart
@immutable
class ShelfTokens extends ThemeExtension<ShelfTokens> {
  const ShelfTokens({
    required this.background, required this.surface, required this.surface2,
    required this.surface3, required this.foreground, required this.text2,
    required this.muted, required this.faint, required this.accent,
    required this.accentSoft, required this.onAccent, required this.border,
    required this.borderSubtle, required this.glow,
  });
  final Color background, surface, surface2, surface3, foreground, text2, muted,
      faint, accent, accentSoft, onAccent, border, borderSubtle, glow;
  // copyWith and lerp as usual
}
```

`ShelfTokens.fromColors(six hex values)` applies the derivation formulas above. `ThemeData` is then built from it: `ColorScheme` (`surface`, `primary` = accent, `onPrimary` = onAccent), `TextTheme` from `google_fonts` (`plusJakartaSans`) with the type table, and component themes (`FilledButtonTheme`, `InputDecorationTheme`, `DialogTheme`, `SwitchTheme`, `TabBarTheme`) using the radii and heights from the tokens file.

### Suggested layout of the client

```text
client-flutter/
  lib/
    design/        tokens, ShelfTheme, shared widgets (cover, chip, panel, bulk bar, ...)
    api/           client generated from backend/openapi.json (openapi-generator, dart-dio)
    features/      one folder per screen group (library, entry, steam, csv, account, themes, space)
    app.dart       router (go_router) and providers
  test/            pure logic ported with its tests: sorting, filtering, grouping, categories, themes
```

### Packages

- API client: `openapi-generator` (dart-dio) from `backend/openapi.json`; JWT as a Bearer header from a secure store (`flutter_secure_storage`).
- State: Riverpod; routing: `go_router`.
- Images: `cached_network_image`, loading covers through the backend's `GET /api/images/proxy`.
- Streams (progress events): server-sent events from the sync and import endpoints through a small SSE reader on `dio`.
- Desktop: `window_manager` for the title bar, `desktop_drop` if file drop is wanted for CSV import.
- Logic to port with tests first: `sortEntries`, `filterEntries`, `groupEntries`, `categories`, `themes`, `reviewStars`, `statusStyle`, `entryChanges` (see `frontend/src/lib/`).

### Packaging and updates

The open questions about installers, signing and the updater are researched in issue #240 (comment "Research: packaging, signing and updater for a Flutter desktop client").

## Keeping this in sync

The web frontend does not use these tokens yet. If the redesign is applied to the web app first, port `shelf.tokens.json` into `frontend/src/styles/globals.css` as the new `--t-*` mapping and keep this document as the contract. A change to a token or component starts here, then the tokens file, then the clients.

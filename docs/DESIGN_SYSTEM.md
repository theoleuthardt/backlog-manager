# Shelf design system

"Shelf" is the redesign direction for Backlog Manager: cover-first like a console home screen, built as a clean desktop application rather than a website in a window. Games are the content, the chrome stays quiet, and one accent colour carries focus and progress.

This document is the spec a second client (the planned Flutter client, issue #240) is built from. It does not depend on the web frontend's code. Related files, all in [`design/`](design/):

- [`README.md`](design/README.md): what the design files are and how to update them
- [`shelf.tokens.json`](design/shelf.tokens.json): every token below in machine-readable form
- [`canvas/`](design/canvas/): the design canvas export, one artboard file per screen plus `shelf.css`
- The live canvas (private to the owner): <https://claude.ai/artifact/GNWoHDeo9QcksZDmpK8nGd>
- [`DASHBOARD_UX.md`](DASHBOARD_UX.md): behaviour decisions of the dashboard that the new layout keeps

## Principles

1. **An app, not a page.** Fixed window with a title bar, sidebar, toolbar and status bar. Only the content area scrolls. No marketing hero, no page-style layouts.
2. **Covers first.** The cover art is the largest thing on every content screen. Text sits on it or directly beneath it.
3. **Master and detail.** Selecting a game opens an inspector beside the list instead of covering it. Short tasks (add, export, find the right game) are sheets over the window.
4. **One accent.** A single accent colour marks the primary action, progress, selection and focus. Everything else is neutral.
5. **Dense but calm.** 32 px controls, 14 px text, hairline dividers between panes, soft filled groups instead of boxes.
6. **Keyboard first.** Cmd/Ctrl+K opens a command palette, `/` focuses search, context menus show their shortcuts.
7. **Changes save themselves.** Entry edits and settings autosave; destructive actions ask first.
8. **Themeable from six colours.** Users keep the six-colour theme model; every other colour is derived.
9. **A bit of space in every theme.** OLED black by default, a starfield, nebula clouds and glowing accents. Every theme has the same atmosphere in its own colours (light: white with blue and red). It stays behind the content and never competes with the covers.

## Theme model and tokens

### Six input colours

A theme is six hex colours, unchanged from the current app (`frontend/src/lib/themes.ts`): `background`, `surface`, `foreground`, `accent`, `border`, `glow`.

| Role | Used for |
|---|---|
| `background` | Window and content background, text on `accent` fills |
| `surface` | Sidebar, status bar, inspector, grouped sections, sheets |
| `foreground` | Primary text, active chip, icons |
| `accent` | Primary buttons, progress, selection ring, focus ring, active tab underline, hover row in menus |
| `border` | Strong outlines: secondary button border, dashed "add" chips, menu border |
| `glow` | Nebula tint of the window background, the sidebar's active item, cover shadows and the home card; Shelf OLED uses violet `#7c5cff` |

### Derived colours

Computed from the six inputs, so a custom theme automatically gets a complete palette:

| Token | Formula | Shelf OLED value |
|---|---|---|
| `surface2` | mix(`surface`, `foreground`, 3%) | `#121216` |
| `surface3` | mix(`surface`, `foreground`, 6%) | `#1a1a20` |
| `borderSubtle` | mix(`surface`, `foreground`, 8%) | `#1c1c22` |
| `text2` | mix(`foreground`, `background`, 11%) | `#d9d9dd` |
| `muted` | mix(`foreground`, `background`, 35%) | `#a3a5ad` |
| `faint` | mix(`foreground`, `background`, 60%) | `#6a6c75` |
| `accentSoft` | `accent` at 14% opacity | amber at 14% |
| `glowSoft` | `glow` at 16% opacity | violet at 16% |
| `onAccent` | black or white, whichever has the higher contrast against `accent` | `#1a1103` |

Semantic colours do not change with the theme (adjusted for contrast on light backgrounds): success `#34d399`, danger `#ff6b81`, info `#60a5fa`.

### Built-in themes

The four built-in themes keep their ids. `light` gets a new palette (white, blue, red) so the atmosphere reads on a light background; `colorful`, `freaky` and `dark` keep their six colours. **Shelf OLED** is new and becomes the default; the former default `dark` (black with a blue accent) stays selectable.

| Theme | background | surface | foreground | accent | border | glow |
|---|---|---|---|---|---|---|
| `shelfOled` (new default) | `#000000` | `#0b0b0e` | `#f2f2f3` | `#f5a524` | `#34343c` | `#7c5cff` |
| `dark` | `#000000` | `#0f0f12` | `#ffffff` | `#2563eb` | `#ffffff` | `#3b82f6` |
| `light` (recoloured) | `#f7f8fd` | `#ffffff` | `#12152b` | `#2f5bff` | `#c3cae3` | `#ff4d6d` |
| `colorful` | `#0b0720` | `#1a1240` | `#fdf2ff` | `#ff3ea5` | `#7c4dff` | `#22d3ee` |
| `freaky` | `#04040e` | `#0e0e26` | `#eaffe9` | `#a3ff12` | `#00ffd0` | `#ff00e5` |

Open point: on the old themes `border` is a bright colour (white, indigo, cyan). Shelf uses it only for strong outlines and uses `borderSubtle` for dividers, so those themes look calmer than before. Whether to soften them is a design decision for the port.

### Typography

Font: **Plus Jakarta Sans** (weights 400 to 800). Sizes in logical pixels; the base size is 14, a desktop scale.

| Style | Size / line height | Weight | Tracking | Use |
|---|---|---|---|---|
| `hero` | 30 / 1.1 | 800 | -0.02em | Title of the "continue playing" card |
| `page` | 26 / 1.1 | 800 | -0.02em | Window or sheet title |
| `section` | 16 / 1.25 | 800 | -0.01em | Shelf and group headings |
| `groupTitle` | 13 / 1.3 | 800 | 0 | Titles of grouped settings sections |
| `body` | 14 / 1.4 | 400 | 0 | Default text |
| `control` | 13 / 1.2 | 600 | 0 | Buttons, segmented controls, tabs |
| `label` | 12 / 1.3 | 600 | 0 | Field labels |
| `caption` | 12.5 / 1.3 | 400 | 0 | Secondary text in rows, hints |
| `eyebrow` | 11 / 1.2 | 700 | 0.12em | Uppercase kicker, accent colour |
| `sidebarLabel` | 11 / 1.2 | 700 | 0.08em | Uppercase sidebar section labels, `faint` colour |
| `coverTitle` | 15 / 1.1 | 800 | 0 | Title printed on a cover without art |

### Spacing, radii, elevation, motion

- **Spacing:** 4, 6, 8, 10, 12, 14, 16, 20, 24, 32. Content padding is 24 horizontally and 22 vertically; dividers are 1 px `borderSubtle`.
- **Radii:** control 8, card (cover) 12, panel and group 14, dialog and sheet 16, window 12, chip full pill. Only chips are pills.
- **Elevation:** only floating layers cast a shadow: menus, sheets, toasts, windows on the desktop, the segmented control's selected thumb. Menus, sheets and desktop windows add a faint `glow` ring or halo (see `elevation` in the tokens file). Panes and groups are flat.
- **Motion:** 150 ms for hover, press and menus, 250 ms for the inspector sliding in and sheets dropping 8 px from the title bar. Ease-out everywhere. With reduced motion enabled there is no slide.
- **Focus and selection:** keyboard focus is a 2 px accent outline with a 2 px offset. A selected cover gets a 3 px accent outline with a 3 px offset and, in selection mode, a 22 px check circle.

### Atmosphere

A space look in the window background and a few glowing accents. It is part of every theme and takes its colours from the theme, so a light theme gets blue and red stars on white, a dark one white and violet. Content stays crisp: the effects sit behind panels and never inside forms or tables.

- **Nebulae:** three radial clouds painted behind the content: `glow` at 30% top right (900 x 640), `accent` at 12% bottom centre (820 x 460), and a mix of both at 16% on the left edge (760 x 520).
- **Stars:** a dense field of 1 to 1.5 px dots in three colours (`starA` foreground, `starB` accent, `starC` glow) in five staggered tiles from 120 x 110 to 340 x 310 px, plus two layers of brighter 1.5 to 2 px stars with a soft 7 to 8 px halo, so the pattern never visibly repeats.
- **Glass:** title bar, sidebar, inspector and status bar are translucent (42 to 52% of `background`) with a blur so the sky shows through; groups and tables are `surface` at 62% with a blur. The edge lines of the sidebar and inspector fade from `glow` to `border`, and the title bar's bottom line glows in the middle.
- **Glows:** primary buttons use an accent gradient with a soft glow; progress bars use the same gradient with a glow; covers cast a `glow`-coloured shadow; selected covers, the active switch, the avatar and the status dot glow; the active sidebar item has a `glow` gradient and a 2 px accent bar; the window has a faint inner `glow`.
- **Details:** a four-point star before section headings, orbit rings with small glowing satellites on the home card, and a planet-with-ring brand mark in the sidebar.
- **Derivation:** custom themes derive the atmosphere from their six colours (see `atmosphere.derivation` in the tokens file). The four built-ins override it with tuned values: Shelf OLED violet, amber and blue; light blue and red; colorful cyan, magenta and violet; freaky magenta, lime and cyan.
- **Motion:** nothing animates, so reduced motion needs no change. Keep the effects out of tables and forms, and cap the blur on slower machines.

### Layout

Reference window 1440 x 900. All sizes are logical pixels.

| Part | Size |
|---|---|
| Title bar | 52 high; window controls, sidebar toggle, back and forward, title, search field (340 wide, shows the Cmd/Ctrl+K hint) |
| Sidebar | 232 wide, translucent `surface`, right divider; brand mark on top, navigation, and the account row (avatar, name, email, switcher) pinned to the very bottom on every window that has a sidebar |
| Toolbar | 48 high under the title bar: title and count on the left, primary actions on the right; turns into a contextual bar (accent-tinted) while a selection is active |
| Filter bar | 44 high under the toolbar on list screens: filter tokens on the left, owned-only switch, reset, sort and view toggle on the right |
| Content | fills the rest, scrolls vertically, 24 px padding |
| Inspector | 380 wide on the right, `surface`, left divider; closes with its button or Esc |
| Status bar | 28 high; counts on the left, sync state and version on the right |
| Controls | 32 high (inputs 34), table rows 48, table header 34, sidebar items 32, setup stepper steps 36 |
| Covers | 2:3, at least 150 wide (140 beside the inspector), gap 22 / 16 |

## Window shell

- **Main window:** title bar, then sidebar plus main pane (toolbar, content, optional inspector), then status bar. The sidebar groups navigation: Backlog (Home, Library, Shared space), Add (Add game, Steam sync, Import CSV, Export CSV), Personalise (Appearance, Settings). It can be collapsed from the title bar.
- **Platform chrome:** macOS shows traffic lights top left inside the title bar; Windows and Linux put caption buttons top right and the title bar content shifts left. The title bar is a drag region except for its controls.
- **Sheets:** short tasks (add a game, find the right game, export) appear as a sheet dropping from the title bar over a dimmed window. A sheet has a head, a body and a footer with the primary action on the right and "Cancel" with an Esc hint on the left.
- **Separate windows:** Settings (1000 x 740, own tab list, grouped form rows), the setup wizard (880 x 640, vertical stepper) and sign-in (440 x 560, two-factor in a second window of the same size) are windows of their own, not panes of the main window.
- **No marketing page:** the landing page belongs to the web build only and is not part of the desktop app. The app opens straight to sign-in, then Home.

## Components

Each component lists its parts and states. The "Flutter" column is a suggestion, not a requirement.

| Component | Anatomy and states | Flutter |
|---|---|---|
| **Title bar** | Window controls, toggle, back/forward, title, search field with Cmd/Ctrl+K hint | `window_manager` for the frame; custom row |
| **Sidebar** | Brand mark, section labels, items 32 high with icon, label and optional count; active item with a `glow` gradient and a 2 px accent bar | custom `ListView` |
| **Account row** | 58 high, divider above, always the last element of the sidebar: gradient avatar, name, email, switcher button | custom row |
| **Toolbar** | Left: view and sort controls; right: counts and primary actions. Selection variant: tinted bar with the count and bulk actions | custom row |
| **Button** | Radius 8, 32 high. Primary (accent fill, `onAccent` text), secondary (strong border), quiet (no border, muted text), danger (danger text), icon (32 square). Hover lifts to `surface2`; focus ring; disabled 40% | `FilledButton`/`OutlinedButton`/`TextButton` themed |
| **Chip** | Pill, 24 high. Neutral, active (`foreground` fill), accent (`accentSoft`), ok (success tint), add (dashed border) | `Chip` |
| **Segmented control** | Track on `surface2`, radius 8, selected segment on `surface3` with a soft shadow | `SegmentedButton` themed |
| **Tabs** | Text tabs, active one with a 2 px accent underline | `TabBar` |
| **Field** | Label above (12 muted), 34 high input on `surface2` with `borderSubtle`, radius 8, hint below in `faint` | `TextField` + `InputDecorationTheme` |
| **Form group** | `surface`, radius 14. Title, optional description, then rows of label (left, with optional small description) and control (right), 1 px dividers; used for settings, creation tool and mapping | `Card` with row children |
| **Switch** | 38 x 22 pill, on = accent | `Switch` themed |
| **Cover** | 2:3, radius 12, title bottom-left when there is no art; optional thin progress bar and meta line beneath. Selected: accent outline; selection mode adds the check circle | `AspectRatio` + `ClipRRect` + `CachedNetworkImage` |
| **Cover grid and shelf row** | Auto-fill grid of covers; shelf row is a horizontal, non-wrapping row of 150-wide covers | `SliverGrid` / horizontal `ListView` |
| **Data table** | Header row (uppercase caption), 48 high rows with checkbox, thumbnail, title, columns, trailing chip or button; hover and selected (`accentSoft`) rows | `DataTable` or custom rows |
| **Inspector** | Header with status ("All changes saved") and close, body with cover and title, tabs, description, beat-time bars, owned switch; footer with Delete, Wrong game, Change cover | custom pane in a `Row` |
| **Context menu** | `surface2`, radius 10, 1 px strong border, items 30 high, hovered item filled with accent, shortcut hints on the right, separators, danger item last, submenus | `MenuAnchor` / `ContextMenuRegion` |
| **Filter bar** | 44 high strip: filter icon, one token per active filter (field in muted, value, remove x), a dashed "+ Add filter" token, right-aligned owned-only switch, reset, sort button and grid/list toggle | custom row |
| **Add-filter menu** | Menu anchored under "+ Add filter": search field "Filter by...", list of fields (genre, platform, interest, review stars, play and beat times), each opening a value picker | `MenuAnchor` with custom children |
| **Command palette** | Sheet 640 wide: input with Esc hint, sections "Games" and "Actions", highlighted row, shortcuts | `showDialog` with a list |
| **Sheet** | `surface`, radius 16, strong border, shadow; head, body, footer on `surface2` | `Dialog` |
| **Stepper (vertical)** | Numbered steps; done = success circle with a check, current = accent, upcoming = faint | custom |
| **Status bar** | `surface`, 12 px text | custom row |
| **Toast** | `surface2`, radius 10, optional action ("Undo") | `ScaffoldMessenger` |

## Interaction patterns

- **Open an entry:** a click selects a cover and opens the inspector on the right; the list stays visible. The window owns this one inspector, so an entry that moves to another group (after a category or status change) stays open. Enter on a focused cover does the same.
- **Autosave:** edits in the inspector and in settings save about 800 ms after the last change; the header shows "Saving..." then "All changes saved". A failed save shows "Not saved" and a toast; pending changes are saved on close.
- **Filtering:** every active filter is a token in the filter bar; click its x to remove it, click its text to edit it. "+ Add filter" opens a searchable field menu, then a value picker. Filters combine with AND; "Reset" clears all. The status bar shows how many filters are active.
- **Selection mode:** the "Select" button, or "Select" in the context menu, turns covers into checkable cards and replaces the toolbar with a contextual bar (count, select all, clear, set status, categories, delete, done). Deleting is always confirmed.
- **Context menu (right click):** open details, select, move to status (submenu), categories (checkable submenu that stays open), delete.
- **Command palette:** Cmd/Ctrl+K searches games and runs actions (add game, sync Steam, sync IGDB, open settings). Arrow keys move, Enter runs, Esc closes.
- **Drag and drop:** in the status sort a cover can be dragged onto another status group; in the category sort onto a category group (adds it and removes the first one). Empty groups stay visible as drop targets. A toast offers "Undo" for a status change.
- **Search more:** the "find the right game" sheet has a "Can't find your game? Search more" button that repeats the search in deep mode (other spellings, bundles) and marks results found that way.
- **Long operations** (Steam and IGDB sync, CSV import) show a progress bar fed by the server's progress events; the sheet cannot be closed while it runs.
- **Keyboard:** `/` or Cmd/Ctrl+K focuses search or opens the palette; Tab reaches every control and shows the focus ring; Esc closes sheets, popovers and the inspector.

## Screens

Routes are the current web routes; the Flutter client can use the same names. Every screen talks to the backend through the OpenAPI client (`backend/openapi.json`).

| Screen | Where | Purpose | Main components | API |
|---|---|---|---|---|
| Sign-in | window | Email and password, then the two-factor code | Two small windows, fields | `POST /api/auth/login`, `POST /api/auth/2fa/login-verify` |
| Setup wizard | window | First run: theme, default sort, Steam, IGDB, done | Vertical stepper, form group | `PUT /api/user/me` |
| Home | main window | Continue playing card, up next and recently completed shelves | Stat tiles, hero card, shelf rows | `GET /api/backlog/entries` |
| Library | main window | All games grouped by status or category; filters, selection, context menu, drag and drop | Toolbar, filter bar, cover grid, contextual bar | `GET/PUT/DELETE /api/backlog/entries*`, `/categories*`, `/statuses*`, `POST /api/igdb-sync/stream`, `POST /api/user/steam/sync/stream` |
| Entry inspector | right pane of the library | Cover, status, categories, times, review, trailer, delete | Inspector, tabs, bars, switch | `PUT/DELETE /api/backlog/entries/{id}`, `GET /api/user/steam/achievements`, `GET /api/games/{steam_app_id}/price`, `GET /api/games/key-shop-prices` |
| Command palette | sheet | Search games, run actions | Sheet, list | local data plus the actions' endpoints |
| Add a game | sheet | Search IGDB, continue in the creation tool | Sheet, data table | `GET /api/games/enriched-search`, `GET /api/games/steam-app-id` |
| Find the right game | sheet | Replace the matched game, "search more" | Sheet, data table | `GET /api/games/enriched-search?deep=true` |
| Cover picker | sheet | Pick another cover | Sheet, cover grid | `GET /api/games/steamgriddb-covers*`, `GET /api/games/steamgriddb-search` |
| Creation tool | main window pane | Create an entry with all fields, personal or shared | Form groups, switch, segmented control | `POST /api/backlog/entries`, `GET /api/backlog/entries/duplicates` |
| Steam sync | main window pane | Preview and import library and wishlist | Segmented control, data table, progress | `POST /api/user/steam/library/preview/stream`, `.../import/stream`, `GET .../wishlist/preview`, `POST .../wishlist/import/stream` |
| CSV import | main window pane | Map columns, preview, import | Form group, data table with result chips | `POST /api/csv/headers`, `/preview/stream`, `/submit/stream` |
| CSV export | sheet | Download the backlog as CSV | Sheet, form group | `GET /api/backlog/entries` (CSV built client-side) |
| Appearance | main window pane | Built-in and custom themes with live preview | Theme list, form group, preview window | `PUT /api/user/me` |
| Shared space | main window pane | Two-person shared backlog, invitations | Toolbar with members, banner, covers with per-member progress | `GET /api/space`, `POST /api/space/invitations*`, `DELETE /api/space/membership` |
| Settings | window | Default sort, two-factor, Steam, IGDB/SteamGridDB keys, Discord alerts, backups, app updates | Tab list, form groups | `GET/PUT/DELETE /api/user/me`, `/api/auth/2fa/*`, `/api/backups*` |

The canvas draws the Settings window on its Integrations tab; the other tabs (General, Security, Backups, App updates, About) use the same form-group layout.

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

`ShelfTokens.fromColors(six hex values)` applies the derivation formulas above. `ThemeData` is then built from it: `ColorScheme` (`surface`, `primary` = accent, `onPrimary` = onAccent), `TextTheme` from `google_fonts` (`plusJakartaSans`) with the type table, `visualDensity` compact, and component themes (`FilledButtonTheme`, `InputDecorationTheme`, `DialogTheme`, `SwitchTheme`, `TabBarTheme`, `MenuTheme`) using the radii and heights from the tokens file.

### Window and layout

- Frame: `window_manager` for a hidden native title bar, custom drag region, and platform caption buttons; the title bar is the 52 px row from the layout table.
- Main window: a `Column` of title bar, a `Row` of sidebar and an `Expanded` main pane (toolbar plus content, optional inspector), and the status bar. Collapsing the sidebar animates its width with the base duration.
- Secondary windows (Settings, setup, sign-in): either a second native window (`desktop_multi_window`) or full-size routes with the same window chrome; decide in the spike.
- Shortcuts: `CallbackShortcuts` or `Shortcuts` + `Actions` for the palette, search, new game and settings.
- Atmosphere: paint the starfield with a `CustomPainter` (fixed random seed so it does not flicker on resize; colours from `ShelfTokens`), the three nebulae with `RadialGradient`s, and the glass bars with `BackdropFilter`; make the blur optional because it can be slow on some Linux setups. All atmosphere colours live in `ShelfTokens`, so a theme change repaints it.

### Suggested layout of the client

```text
client-flutter/
  lib/
    design/        tokens, ShelfTheme, shell widgets (title bar, sidebar, status bar), shared widgets (cover, chip, table, sheet, menu)
    api/           client generated from backend/openapi.json (openapi-generator, dart-dio)
    features/      one folder per screen group (library, entry, steam, csv, settings, themes, space)
    app.dart       router (go_router) and providers
  test/            pure logic ported with its tests: sorting, filtering, grouping, categories, themes
```

### Packages

- API client: `openapi-generator` (dart-dio) from `backend/openapi.json`; JWT as a Bearer header from a secure store (`flutter_secure_storage`).
- State: Riverpod; routing: `go_router`.
- Images: `cached_network_image`, loading covers through the backend's `GET /api/images/proxy`.
- Streams (progress events): server-sent events from the sync and import endpoints through a small SSE reader on `dio`.
- Desktop: `window_manager`, `desktop_drop` if file drop is wanted for CSV import.
- Logic to port with tests first: `sortEntries`, `filterEntries`, `groupEntries`, `categories`, `themes`, `reviewStars`, `statusStyle`, `entryChanges` (see `frontend/src/lib/`).

### Packaging and updates

The open questions about installers, signing and the updater are researched in issue #240 (comment "Research: packaging, signing and updater for a Flutter desktop client").

## Keeping this in sync

The web frontend does not use these tokens or this shell yet. If the redesign is applied to the web app first, port `shelf.tokens.json` into `frontend/src/styles/globals.css` as the new `--t-*` mapping and keep this document as the contract. A change to a token or component starts in the design canvas, then `design/canvas/` and `shelf.tokens.json`, then this document, then the clients.

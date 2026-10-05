# Design files

Source of the Shelf redesign. The written spec is [`../DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md); this folder holds the files it is drawn from.

| Path | What it is |
|---|---|
| `shelf.tokens.json` | Design tokens (colour model, type, spacing, radii, layout) in machine-readable form |
| `canvas/` | Export of the design canvas: one `.dc.html` file per artboard, `canvas.json` (positions and titles) and `shelf.css` (tokens and component classes the artboards use) |

## The canvas

The live canvas is private to its owner: <https://claude.ai/artifact/GNWoHDeo9QcksZDmpK8nGd>. The files in `canvas/` are the same sources, so the design survives without that link.

The `.dc.html` files are Design Component pages. They load `./support.js` and a `<x-dc>` runtime that the canvas provides, so they render only inside the Design canvas (or any tool that supplies that runtime), not when opened directly in a browser. Their markup, inline styles and `shelf.css` are readable on their own and are the reference for spacing, sizes and states.

### Artboards

Chosen direction, drawn as a desktop app (fixed 1440 x 900 windows, or smaller windows on a desk background):

| File | Screen |
|---|---|
| `ShelfDashboard.dc.html` | Home: continue playing, shelves |
| `ShelfDetail.dc.html` | Library with the entry inspector open |
| `ShelfLibrary.dc.html` | Library: filter popover, selection mode, context menu with submenu |
| `ShelfPalette.dc.html` | Command palette (Cmd/Ctrl+K) |
| `ShelfAdd.dc.html` | Add a game (sheet) |
| `ShelfWrongGame.dc.html` | Find the right game, "search more" (sheet) |
| `ShelfCreate.dc.html` | Creation tool |
| `ShelfSteam.dc.html` | Steam sync preview table |
| `ShelfImport.dc.html` | CSV import: column mapping and preview |
| `ShelfExport.dc.html` | CSV export (sheet) |
| `ShelfThemes.dc.html` | Appearance: theme list, editor, live preview |
| `ShelfSpace.dc.html` | Shared space |
| `ShelfAccount.dc.html` | Settings window (integrations tab shown) |
| `ShelfLogin.dc.html` | Sign-in and two-factor windows |
| `ShelfSetup.dc.html` | Setup wizard window |

Shared building blocks, imported by the artboards: `SidebarNav.dc.html`, `Titlebar.dc.html`, `StatusBar.dc.html`, `LibraryPane.dc.html` (the library behind sheets).

Explored and not chosen (kept for reference): `Main.dc.html` and `ArcadeDetail.dc.html` (A, Arcade: gaming HUD, neon on near-black), `CleanDashboard.dc.html` and `CleanDetail.dc.html` (B, Clean: light and minimal). Their file names predate the others.

### Updating

Edit in the Design canvas, then re-export the files into `canvas/` so this folder and the canvas do not drift apart. If a token changes, also change `shelf.tokens.json` and the tables in `DESIGN_SYSTEM.md`.

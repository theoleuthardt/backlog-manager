# Dashboard UI/UX: brainstorm and design decisions

Result of issue #150 ("Dashboard UI Enhancement Brain Storming") and its
sub-issues #48 (sort by), #97 (theming), #177 (navbar search), #178
(grouping) and #63 (responsive design). The first half records what was
built and why; the second half is the idea backlog that did *not* make
it into this round, so the next round can start from it.

## What was built

### Sort by and filter sidebar (#48)

- The left bar is split into a **Sort by** and a **Filter** section. Sort
  options: status (default), category, genre, playtime, platform, interest
  level, review stars, plus an ascending/descending toggle.
- Text-like keys (status order, genre, platform, category) default to
  ascending, numeric keys (playtime, interest, review stars) to
  descending - the direction resets when the sort option changes.
- Entries missing the sort key (no playtime, no genre, uncategorized)
  always sort **last**, in both directions.
- The default sort is a per-account setting (`users.default_sort`, Account
  page) so the dashboard opens the way the user wants on every device.
- "Category" is resolved client-side from the existing category endpoints,
  because backlog entries do not embed their categories. It only runs
  while that sort is selected.
- Two latent filter bugs went away with the rewrite: the playtime slider
  used to be capped at whatever `maxPlaytime` was on the first render
  (100h before the data loaded), silently hiding longer games, and the
  interest/review sliders started at 1 so entries with a value of 0
  disappeared. A range filter is now inactive (`null`) until the slider is
  actually moved.

### Categories

The backend always had categories (per-user, coloured, many-to-many with
entries) but nothing in the UI used them, so the "category" sort option from
#48 was empty. They are now usable end to end: the entry dialog hero shows
an entry's categories as coloured chips next to the status, with a popover
to toggle existing ones or create a new one (assigned immediately) and a
manage dialog to rename, recolour and delete. The sidebar gets a Category
filter once at least one exists, and sorting/grouping by category uses the
entry's first category alphabetically (uncategorized last), tinted with the
category colour. Names are unique per user case-insensitively in the UI
because they double as the filter key, and a filter on a renamed or deleted
category is dropped instead of silently hiding everything. The API now
validates names (1-100 characters) and colours (`#rrggbb`) at the boundary.

### Search in the navbar (#177)

The search field moved out of the filter bar into the middle of the
dashboard navbar (full width, second row on phones). `/` and `Ctrl/Cmd+K`
focus it. The text lives in a small `DashboardContext` because the navbar
and the entry grid are siblings in the page tree.

### Grouping by status with drag and drop (#178)

The issue itself concluded that grouping only makes sense for statuses; in
practice every sort option now shows headlines, and only the status
groups are drag-and-drop targets. Other options group by the same key the
sort uses: first genre, first platform (so an entry sits in one group
only), category, interest level, review stars (0 and missing are
"Unreviewed") and playtime buckets (not played, under 10h, 10-50h,
50-100h, 100h or more). Sorting by status renders one group per status with a headline, a count, a
collapse toggle and a coloured accent. Empty statuses stay visible as
dashed drop targets. Dragging a card onto another group changes its status
optimistically, with a toast that offers **Undo**. Mouse needs an 8px
movement and touch a 250ms press before a drag starts, so clicking a card
still opens it and scrolling on a phone still works.

### Theming (#97)

- Themes are **six colours** (background, surface, text, accent, border,
  glow) applied as `--t-*` CSS custom properties on `<html>`. Built-in:
  Dark (the previous look), Light, Colorful (gradient + glow) and Freaky
  (animated neon orbs, wobbling cards, flickering headlines; all motion
  respects `prefers-reduced-motion`).
- Custom themes come from the **theme creator** (`/themes`): colour
  pickers with live preview across the whole app, "start from" a built-in
  theme, save/edit/delete, up to 10 per account. Colours are validated as
  `#rrggbb` on the backend because they end up in CSS.
- The active theme and custom themes are stored on the account
  (`theme`, `custom_themes`) and cached in `localStorage`; an inline script
  re-applies the cache before first paint, so a reload never flashes the
  default theme.
- Existing components were not rewritten class by class: Tailwind's
  `black`/`white` colours are aliased to the theme background/text
  (`--color-black: var(--t-background)`), which makes `bg-black text-white
  border-white` follow the theme. New code should prefer the semantic
  tokens (`bg-background`, `bg-surface`, `text-foreground`, `bg-primary`).
- The white PNG icon set is recoloured with the `themed-icon` class (a
  filter derived from the text colour), so it stays visible in light themes.

### Modal redesign

The entry dialog is no longer a stack of labelled inputs: a hero with the
blurred cover, title, genre/platform chips and status; HUD tiles for
playtime, a 10-segment interest meter and an ownership toggle; tabs for
overview, progress (HowLongToBeat bars against your playtime, achievements)
and review/notes; a fixed action bar with delete and update. Grid cards now
show the title, a status badge and a playtime-vs-main-story progress bar on
the cover itself.

### Responsive design (#63)

Below `md` the navbar icons collapse into a **burger menu** (animated
three-line icon, a panel with labelled rows; the add/import/export entries
use text variants) next to the theme picker, and the search field moves to
its own row. Below `lg` the sort/filter sidebar is a **bottom sheet**: a
"Sort & filter" button (with the active-filter count) in a toolbar that
stays pinned to the top of the screen while scrolling, so it is reachable
from anywhere in a huge backlog, opens a panel that slides up, can be dragged down or tapped away, and pins a "Show N
games" button in thumb reach while the list updates live behind it. The
grid centres its fixed-width cards, and the entry dialog is full screen on
phones. All pages were checked at 375px and 768px.

## Idea backlog (not built yet)

- **Play-next roulette**: a "pick something for me" button that weighs
  interest against how short the game is, with a slot-machine animation.
- **Stats strip** above the grid: total hours played, completion rate,
  backlog "debt" in hours (sum of main-story time of everything not
  started) and a streak of games completed per month.
- **Completion ring** on every card instead of the thin bar, and a
  confetti burst when a game moves to Completed.
- **Achievement shelf**: trophy cabinet page built from the Steam
  achievement data that is already fetched.
- **Drag and drop between category groups** (a card can belong to several
  categories, so this needs a move-versus-add decision).
- **Command palette** (`Cmd+K`) that combines search, sort, theme switching
  and navigation instead of only focusing the search field.
- **Density toggle**: compact list rows versus large covers, remembered per
  account.
- **Animated icons**: small Lottie/`motion` icons for status changes and the
  navbar instead of GIFs, so they follow the theme colours.
- **Gamepad/keyboard navigation** through the grid, with keyboard-operated
  drag and drop.
- **Theme extras**: import/export a theme as JSON, share codes, per-theme
  background image.
- **Saved views**: store a filter + sort combination under a name.

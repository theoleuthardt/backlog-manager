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

Navbar wraps (search moves below on phones, smaller logo and icon gaps),
the sidebar becomes a collapsible panel above the grid below `lg`, the
grid centres its fixed-width cards, and the entry dialog is full screen
on phones. All pages were checked at 375px and 768px.

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
- **Custom groups / collections** beyond status, reusing the existing
  categories backend (assign categories from the entry dialog, group by
  category with the same drag and drop).
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

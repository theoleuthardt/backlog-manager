# Review of PR #298: feat(app): port the pure frontend logic to Dart with its tests

- Reviewer: GLM
- Branch: `258-port-frontend-logic`, commit reviewed: 370963e
- Issue: #258
- Checks run: `task app:lint` (pass), `task app:test` (pass, 138 tests), `task app:format:check` (pass, 0 changed) — all at commit 370963e; `task app:test` independently re-run by the reviewer (pass, 138 tests). Additional standalone Dart probes confirmed `Uri.tryParse` semantics, `List.sort` instability, `double.toString()` and `String.trim()` behaviour; a Node probe confirmed the WHATWG-URL/`Number()` side of each comparison.

## Summary

The PR ports the framework-free logic of `frontend/src/lib/` (sort, filter, group, categories, themes, status style, entry changes, field diffs, split list, trailer, backups, setup wizard, safe URL) to Dart in `app/lib/domain/` with app models and API mappers, plus a TypeScript→Dart mapping table in `docs/FLUTTER.md`. The port quality is high and the parity criterion (functions 1:1 like the current Vite/React frontend, per the repo owner) is met for the tested cases: every applicable vitest case in the ported suites has a Dart equivalent, usually verbatim, and the deliberate deviations (CSS variables → `onAccentColor`/`iconsNeedInversion`, `reviewStars` deferred to the star control, `compareText` replacing `localeCompare`) are documented. The most important problems are behaviour divergences the ported tests cannot see — `isHttpUrl` accepts edge-case URLs the WHATWG-based TypeScript original rejects (and vice versa), and Dart's unstable `List.sort` can order fully-tied entries differently than the web — plus several smaller undocumented divergences and one weakened test.

## Findings

### `isHttpUrl` accepts URLs the TypeScript version rejects, and vice versa (minor, confirmed)
- Location: `app/lib/domain/safe_url.dart:3-7` (TS: `frontend/src/lib/safeUrl.ts`)
- Problem: The TS original delegates validation to the WHATWG `new URL(value)`, which *validates*; Dart's `Uri.tryParse` only parses structure. The two disagree on real inputs, so the Flutter app will treat a different set of third-party links as safe to open — a functional divergence in a security-relevant helper (the function's own docstring says it guards links "the backend or a third party supplied").
- Evidence (probe output, Dart 3.x on this machine vs `new URL` in Node):
  - `isHttpUrl('https://')`: Dart — `Uri.tryParse` succeeds, `hasAuthority` is true with an empty host → returns true. TS — `new URL('https://')` throws (empty host invalid for a special scheme) → false.
  - `isHttpUrl('https:example.com')`: TS — WHATWG treats a special scheme without `//` as an authority (`new URL('https:example.com').href === 'https://example.com/'`) → true. Dart — `hasAuthority` false → false.
  - The ported test asserts agree on all nine cases, so the suite cannot catch this. Note that `parseServerUrl` in PR #299 (`app/lib/api/server_url.dart:36`) closes the same hole with a `uri.host.isEmpty` check — `safe_url.dart` lacks it.
- Suggested fix: require a non-empty host: `if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;`. Then decide the `https:example.com` direction (either mirror WHATWG by re-parsing, or document the stricter behaviour in `docs/FLUTTER.md`) and add both cases to the test.

### Identical entries can reorder differently than on the web (minor, confirmed)
- Location: `app/lib/domain/sort_entries.dart:84-97` (comparator uses `compareText(a.title, b.title)` as final tie-break)
- Problem: JS `Array.prototype.sort` is guaranteed stable (ES2019+); Dart's `List.sort` is documented as not stable. `compareText('Zelda', 'Zelda')` returns `0`, so two entries with the same title and equal sort keys — duplicate titles are allowed by the backend — can come out in a different order than the web client's dashboard, changing tile positions between the two clients.
- Evidence: probe run with Dart's `List.sort` on comparator-equal records (key 0, ids in input order 0..5): output ids `[1, 3, 5, 2, 4, 0]` — input order not preserved, first inversion at index 1.
- Suggested fix: add a final `id` tie-break in `sortEntries` when `compareText` returns 0 (making the Dart order deterministic and identical to the web's stable order), or document the divergence in `docs/FLUTTER.md` alongside the `compareText` note.

### `sortCategoriesByName` diverges from `localeCompare(base)` for accented names (minor, confirmed)
- Location: `app/lib/domain/categories.dart:36-39` (TS: `frontend/src/lib/categories.ts:39-45`)
- Problem: The TS original sorts with `a.name.localeCompare(b.name, undefined, { sensitivity: "base" })`, which folds accents (`é` collates as `e`). The Dart port compares lowercased code units (`a.name.toLowerCase().compareTo(b.name.toLowerCase())`), so `'éco-op'` lands after `'zombies'` in Dart (é = U+00E9, 233 > 122) but before it on the web. `docs/FLUTTER.md:61` documents the accent divergence only for `compareText`; `sortCategoriesByName` bypasses `compareText`, so this divergence is neither covered by the documented substitute nor documented itself.
- Evidence: probe: `'éco-op'.compareTo('zombies')` → `1` (Dart puts `zombies` first); Node `localeCompare` with `sensitivity: "base"` sorts `éco-op` first. No Dart or vitest case covers accented category names.
- Suggested fix: use `compareText(a.name, b.name)` in `sortCategoriesByName` (matching the rest of the port) and add the accented-name case to `app/test/domain/categories_test.dart`; or extend the `docs/FLUTTER.md` note to say category sorting does not fold accents.

### `_formatNumber` renders integral playtime as `"12.0"` where the web client shows `"12"` (minor, confirmed)
- Location: `app/lib/domain/diff_fields.dart:64` (TS: `frontend/src/lib/diffFields.ts`)
- Problem: In the duplicate-entry comparison, an entry with a round playtime (12 h) will display `12.0` in the Flutter client but `12` in the web client.
- Evidence: the frontend maps playtime through `Number(...)` (see `frontend/src/lib/api/backlog.ts` `toNumber`), and `String(12)` is `"12"`; the Dart mapper's `toNumber` (`app/lib/api/mappers.dart:6-10`) always returns `double`, and Dart's specified `double.toString()` for an integral double is `"12.0"` (probe: `12.0.toString()` → `"12.0"`). The ported test uses `12.5`, which prints identically in both languages, so the case is invisible to the suite.
- Suggested fix: strip the trailing `.0` for integral values (e.g. `value % 1 == 0 ? value.toInt().toString() : value.toString()`) and add a vitest-parity test asserting `playtime: 12` formats as `"12"`.

### `toNumber` differs from the TS original for `''`, padded and hex strings (minor, confirmed)
- Location: `app/lib/api/mappers.dart:6-10` (TS: `frontend/src/lib/api/backlog.ts:103-107`; pinned by `app/test/api/mappers_test.dart:14-18`)
- Problem: The TS helper uses `Number(value)`: `Number('') === 0`, `Number(' 12 ') === 12`, `Number('0x10') === 16` — all finite, so TS `toNumber` returns `0`, `12`, `16`. The Dart port uses `double.tryParse`, which returns `null` for all three. The Dart test explicitly asserts `toNumber('')` is null, so this is deliberate, but it is not documented in `docs/FLUTTER.md` even though the issue demands 1:1 behaviour. In practice it looks unreachable through the generated client (the backend serializes `numeric` as plain decimal strings or JSON `null`), so there is no production impact — but the helper silently differs from the contract it was ported from.
- Evidence: Node probe `Number(''), Number(' 12 '), Number('0x10')` → `0 12 16`; Dart `double.tryParse` returns null for all three.
- Suggested fix: document the tightening in `docs/FLUTTER.md`'s mapper note, or mirror TS exactly. Given the inputs are unreachable from the API, documenting is enough.

### Dart `diffEntryForm` tests assert fewer fields than their vitest counterparts (minor, confirmed)
- Location: `app/test/domain/entry_logic_test.dart:113-124` (TS: `frontend/src/lib/entryChanges.test.ts:41-54`)
- Problem: The vitest cases assert full-object equality (`expect(diffEntryForm(...)).toEqual({ status: "Completed", note: "great" })` proves *no other field* is in the changes object). The Dart port asserts only `status`, `note`, `genre`, `owned` — a regression that wrongly sets e.g. `interest` or `reviewStars` would pass the Dart suite but fail vitest. A weakened case is a real finding under the parity criterion.
- Evidence: `entry_logic_test.dart:119-122` checks four properties of ten (`imageLink`, `playtime`, `platform`, `interest`, `reviewStars`, `review` are never asserted in the changed case).
- Suggested fix: assert the complete expected `EntryFormChanges` — either add an `==`/`hashCode` to `EntryFormChanges` and `expect(changes, const EntryFormChanges(status: 'Completed', note: 'great'))`, or explicitly expect all ten fields.

### Mapping table omits `frontend/src/lib/` modules it claims to cover (minor, confirmed)
- Location: `docs/FLUTTER.md:39-59` (mapping table)
- Problem: The table (and the sentence above it, "every vitest case that applies has a Dart equivalent") maps every module of `frontend/src/lib/` except `utils.ts` (`cn`, the clsx/tailwind-merge helper) and `buttonStyles.ts` (Tailwind class strings). Neither is ported (correctly — they are web-CSS-only) nor listed as deliberately not ported, unlike `pathWithQuery.ts` and `appUpdate.ts` which get explicit `-` rows. Per the parity rule, deliberate deviations are only acceptable when documented.
- Evidence: `ls frontend/src/lib/` lists `utils.ts` and `buttonStyles.ts`; neither string appears anywhere in `docs/FLUTTER.md` (`grep -n "utils\|buttonStyles" docs/FLUTTER.md` finds nothing).
- Suggested fix: add `-` rows for `utils.ts` and `buttonStyles.ts` ("web-only CSS class helpers"), and one row noting the remaining `api/` wrappers (`auth.ts`, `csv.ts`, `games.ts`, `user.ts`, `twoFactor.ts`) are replaced by the generated client with the SSE reader from #297.

### Unused constants `maxCustomThemes` and `themeNameMaxLength` (nit, confirmed)
- Location: `app/lib/domain/themes.dart:113-114`
- Problem: CLAUDE.md's "No dead code" rule. These two constants (porting `MAX_CUSTOM_THEMES` / `THEME_NAME_MAX_LENGTH` from `frontend/src/lib/themes.ts:81-82`, where the web theme editor and settings use them) have no consumer anywhere in `app/lib` or `app/test` — grep finds only the definitions. Every other `themes.dart` export is used at least by `themes_test.dart`.
- Evidence: `grep -rn "maxCustomThemes\|themeNameMaxLength" app/lib app/test` → only `themes.dart:113` and `themes.dart:114`.
- Suggested fix: delete both until the theme editor/settings screens (#275) need them, or keep them and note in the PR that they are pinned for that upcoming screen.

## Checked and fine

- `sortEntries` ↔ `app/lib/domain/sort_entries.dart`: all 12 sort cases, all 7 `defaultDirectionFor` options and `isSortOption`→`parseSortOption` ported verbatim and passing; missing-key-last in both directions, cleared-review-as-unset, first-genre/platform keys, category map, no-mutation all match
- `filterEntries` ↔ `filter_entries.dart`: all 15 cases ported 1:1 including zero/high values with untouched ranges, search trim + case-insensitivity, inclusive ranges, review-stars 0-vs-missing, all four HowLongToBeat ranges, AND combination, and all 3 `countActiveFilters` cases
- `groupEntries` ↔ `group_entries.dart`: all 10 cases ported; `LinkedHashMap` preserves insertion order exactly like the JS `Map` for status groups, appended unknown statuses, first-appearance label groups; playtime buckets (null/0/5/10/49/50/100) and star singular/plural match; the TS `!playtime` falsy check is faithfully `playtime == null || playtime == 0`
- `categories` ↔ `categories.dart`: all 8 cases ported; `nextCategoryColor` cycling and hex-palette validity match (the TS `?? '#38bdf8'` fallback was dead code in TS and is correctly absent); `categoryNameError` trim/case-insensitive duplicate logic identical
- `themes` ↔ `themes.dart`: all vitest cases ported; `themeCssVariables` deliberately split into `onAccentColor` + `iconsNeedInversion` (documented); NaN-for-malformed-colour behaviour matches TS's `parseInt` semantics with extra Dart tests; `newCustomThemeId` produces the same `custom-` + 8-hex-char id space with a secure RNG
- `reviewStars.ts` not ported: deliberate, documented ("a single constant, added where the star control is built")
- `statusStyle.ts` ↔ `status_style.dart`: identical colours and custom-status fallback; the Dart port adds tests the TS never had
- `splitList.ts` ↔ `split_list.dart`: all 4 vitest cases ported verbatim; split/trim/filter semantics identical. BOM handling also matches: Dart's `trim()` does strip U+FEFF (verified by probe — an earlier suspicion it did not was wrong)
- `trailer.ts` ↔ `trailer.dart`: identical anchored regex (11-char id, `$`-anchored, no multiline), same embed URL, all 4 vitest cases incl. every reject case ported
- `setupWizard.ts` ↔ `setup_wizard.dart`: all 4 vitest cases ported; redirect logic line-for-line
- `backups.ts` ↔ `backups.dart`: all 8 vitest cases ported (five kind labels, raw-kind fallback, pluralisation incl. 0/1, title preference, blank-name-to-null, length-limit pin)
- `entryChanges.ts` ↔ `entry_changes.dart`: all 5 vitest cases ported; `?? ""`/`?? 0`/`?? false` fallbacks preserved through the non-null model defaults and the mapper; unset-playtime skip and `splitList` integration identical
- `diffFields.ts` ↔ `diff_fields.dart`: all 4 vitest cases ported, including the undefined-as-empty rule; field ids and Yes/No formatting identical
- Mappers (`toEntryData`/`toNumber` ↔ `mappers.dart`): `entryFromResponse` matches field-for-field (`image_link ?? ''`, `imageAlt = title`, `in_shared_space ?? false`, `review_stars` keeps `0`); category/custom status/space mappers match the TS shapes
- `largeBacklog.test.ts` ↔ `large_backlog_test.dart`: same 10,000-entry fixture (same `7919` scrambling), same 3 s wall-clock budget, documented; the budget can flake on a loaded CI runner, but the risk is inherited verbatim from the frontend original rather than introduced, and measured runs finish in ~1 s — no change requested
- `compareText` replacing `localeCompare`: case-tie and accent behaviour explicitly documented in `docs/FLUTTER.md:61` (but see the `sortCategoriesByName` finding, which bypasses `compareText`)
- No narrative comments, no commented-out code, no premature abstractions in the ported files; only doc comments in the established style

## Open questions

- `maxCustomThemes` / `themeNameMaxLength` (`themes.dart:113-114`): kept deliberately as part of the ported module surface for the upcoming theme screens (#275), or leftover? (Reported as a nit; the author may legitimately prefer keeping the module surface complete.)
- `toNumber('')` → `null` instead of the TS `0`: intentional tightening? If yes, it deserves a line in `docs/FLUTTER.md`'s mapper note, since the issue's acceptance criterion is 1:1 behaviour.
- `maxBackupNameLength` (`app/lib/domain/backups.dart:9`, public, no underscore) is currently referenced only by its own test; the web client's `MAX_BACKUP_NAME_LENGTH` is used by the backup UI. Is the Flutter backup screen (a later issue) its intended second user?
# Review of PR #296: docs(app): contributor guide and CLAUDE.md rules for the Flutter project

- Reviewer: GLM
- Branch: `288-flutter-docs`, commit reviewed: c494965
- Issue: #288
- Checks run: `task app:lint` (pass), `task app:test` (pass, scaffold suite), `git merge-tree --write-tree origin/main HEAD` (clean merge, MERGEABLE); every documented `task` name verified against `Taskfile.yml` in the trial-merged tree, every referenced path against the tree, doc claims checked against `app/analysis_options.yaml`, `app/pubspec.yaml`, `app/.fvmrc`, `app/macos/Runner.xcodeproj/project.pbxproj` and `.github/workflows/*`

## Summary

The PR adds a Flutter client section to `CLAUDE.md` (commands, layout, state and routing, theming, generated API client, tests and goldens, Dart comment policy, lints), expands `docs/FLUTTER.md` into a contributor guide (setup, commands, running/debugging, tests/goldens, building, architecture note), adds a pointer in `docs/ARCHITECTURE.md` and an `app:test:update-goldens` task. It is docs-only and of good quality: every task name and file path it references exists after the (clean) merge into current main, the `///` comment rule is consistent with the general comment policy, and the analyzer claims are backed by `app/analysis_options.yaml`. The most important problem is that several sentences state app behaviour and infrastructure as present fact that no code on main backs yet (sign-in screen, default server URL, Riverpod/go_router, app CI), and one stale sentence about empty folders survived the rewrite.

## Findings

### Docs state app behaviour and infrastructure as fact that does not exist yet (minor, confirmed)
- Location: `docs/FLUTTER.md:14`, `docs/FLUTTER.md:48`, `docs/FLUTTER.md:54`, `docs/FLUTTER.md:59`, `CLAUDE.md:112-114`
- Problem: A contributor following the merged docs on today's main hits claims that are false. Setup step 4 says "point the app at a running one on the sign-in screen. A debug build talks to `http://localhost:8000` by default" — there is no sign-in screen and nothing consumes a default server URL yet (PR #299 / issue #256). The build section documents `flutter build macos --dart-define=API_URL=...` — no code reads `API_URL` on main. The `CLAUDE.md` layout bullet lists an "SSE reader, server URL" in `lib/api/` and asserts "Riverpod and `go_router`" and "the `ShelfTokens` `ThemeExtension`" — on main `lib/api/` holds only `api_client.dart`, `api_error.dart` and `generated/`, and `app/pubspec.yaml` has neither riverpod nor go_router. Lines 48 and 54 claim "Windows and Linux are checked by the CI runners of those systems" and "Goldens are recorded on the CI platform's fonts" — no workflow in `.github/workflows/` mentions Flutter at all (that is issue #282, not started).
- Evidence: `git ls-tree -r origin/main --name-only app/lib` shows only `api/api_client.dart`, `api/api_error.dart`, `api/generated/…`; `git show origin/main:app/pubspec.yaml` lists dio/json_annotation/retirement only; `grep -in "flutter" .github/workflows/*.yml` finds no match; `grep -rn "API_URL" app/lib` is empty.
- Suggested fix: Either land #297/#299 (and ideally #282) before this PR, or reword the affected sentences to future tense with the issue number (e.g. "will talk to `http://localhost:8000` by default once #251 lands", "CI runners — planned in #282"), matching how the packaging sentence already cites issue #277, and state the intended merge order in the PR body the way it already does for #295.

### Stale ".gitkeep" sentence kept in the rewritten layout section (minor, confirmed)
- Location: `docs/FLUTTER.md:42`
- Problem: "The empty `design/`, `api/` and `features/` folders hold a `.gitkeep` until the issues that fill them land" is wrong for `api/`: since #295 (merged, and part of this PR's clean merge result) it holds `api_client.dart`, `api_error.dart` and the committed `generated/` client. The PR substantially expands the sections directly below this sentence without correcting it, so the guide contradicts itself.
- Evidence: `git ls-tree origin/main app/lib/api/` lists `api_client.dart`, `api_error.dart` and the `generated` tree; the trial-merged `docs/FLUTTER.md` still contains the sentence.
- Suggested fix: Change to "The still-empty `design/` and `features/` folders hold a `.gitkeep` until the issues that fill them land" (and drop `app/lib/api/.gitkeep` if #295 left it committed).

## Checked and fine

- All `task` names the docs reference exist post-merge: `app:install/dev/lint/test/test:update-goldens/format/format:check/build/generate-api`, `backend:openapi`, `db:up`, `backend:dev`; the new `app:test:update-goldens` runs a valid `flutter test --update-goldens`
- "task check and task lint include the app": verified in `Taskfile.yml` (`lint`/`check` call `app:lint`, `test` calls `app:test`, `format`/`format:check`/`install` include their app counterparts)
- Build output paths: `backlog_manager.app` matches `PRODUCT_NAME` in `app/macos/Runner.xcodeproj/project.pbxproj`; Windows/Linux paths are Flutter's standard outputs; `APP_PLATFORM` maps darwin→macos
- Flutter version claim 3.47.6 matches `app/.fvmrc`; hot reload keys and DevTools URL behaviour match `flutter run` semantics; "no cross-compilation for desktop" is accurate
- "strict analyzer settings and rules in `app/analysis_options.yaml`" is backed (`strict-casts`, `strict-inference`, `strict-raw-types`, extra lint rules, `flutter_lints`)
- The Dart comment-policy addition (`///` as an allowed docstring form) is consistent with the general comment policy and the new Flutter section's "Comments" bullet
- `docs/ARCHITECTURE.md` addition is factual; the `app:generate-api` workflow description matches the task
- Branch is based one commit behind main (pre-#295); the merge is conflict-free, so the `app:generate-api` references become valid after merge — not a finding
- `task app:lint` and `task app:test` pass on the branch

## Open questions

- Is the intended merge order #296 → #297/#299 (docs first, describing what lands next), or should this PR wait for them? The PR body pins only the #295 dependency; finding 1's severity depends on the answer.
- Should the CI claims (lines 48/54) block on #282 being scheduled, or is a "planned in #282" note acceptable?
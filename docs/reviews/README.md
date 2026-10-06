# PR Reviews by GLM (2026-10-06)

Findings per PR, one file each (`PR-<number>-glm.md`). Severity scale: critical / major / minor / nit. Every finding is marked confirmed or unverified in its file; the checks run (lint, tests, formatting) are listed per file.

| PR | Title | Critical | Major | Minor | Nit | Verdict |
|----|-------|----------|-------|-------|-----|---------|
| [#296](PR-296-glm.md) | docs(app): contributor guide and CLAUDE.md rules for the Flutter project | 0 | 0 | 2 | 0 | Good docs; several sentences state behaviour and infrastructure as fact that no code backs yet — reword to future tense with issue numbers or land the referenced PRs first. |
| [#297](PR-297-glm.md) | feat(app): server-sent events reader for sync and import progress | 0 | 0 | 0 | 0 | Clean. Careful implementation, canned tests, every candidate issue refuted by experiment; divergences from the TS original are documented and unreachable against this backend. |
| [#298](PR-298-glm.md) | feat(app): port the pure frontend logic to Dart with its tests | 0 | 0 | 7 | 1 | Strong port with verbatim test parity, but several behaviour divergences the tests cannot see (safe-URL edge cases, unstable sort, accent folding, `"12.0"` formatting) need fixing or documenting under the 1:1-parity rule. |
| [#299](PR-299-glm.md) | feat(app): configurable backend URL | 0 | 0 | 2 | 0 | Sound design with the security rule and change-ordering guarantees well tested; two Dart-`Uri` edge cases (out-of-range port, non-ASCII host) pass validation and should be rejected or pinned. |
| [#300](PR-300-glm.md) | feat(backend): API additions for the Flutter client | 0 | 0 | 1 | 1 | Migrations, init SQL, backups and web-client compatibility all done right; the publisher write path has no sender (scope items unimplemented, PR body overstates coverage) and one Bruno doc is stale. |

**Totals: 0 critical, 0 major, 12 minor, 2 nits.**

Review method: each PR was checked out in its own worktree at the branch tip (SHAs in the files); `task` lint/test/format ran there, and claimed bugs were reproduced with standalone Dart/Node probes before being reported. PR #300 is closed/parked (lands with the cutover, #287); its review focused on migration safety, backward compatibility with the web client, backup/restore integrity and the API contract.
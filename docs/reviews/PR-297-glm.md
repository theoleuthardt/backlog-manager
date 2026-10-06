# Review of PR #297: feat(app): server-sent events reader for sync and import progress

- Reviewer: GLM
- Branch: `250-sse-reader`, commit reviewed: 41ba68e
- Issue: #250
- Checks run: `task app:lint` (pass, "No issues found"), `task app:test` (pass, 30 tests), `task app:format:check` (pass, 0 files changed) — all in the branch's worktree at commit 41ba68e. Throwaway probes outside the worktree verified (a) that a Dart stream that errors delivers both `onError` and `onDone` to the consumer, and (b) that Dart's `utf8.decoder` strips a leading UTF-8 BOM the same way the TS `TextDecoder` does.

## Summary

The PR adds a self-contained SSE reader (`app/lib/api/sse.dart`, 179 lines) on top of the app's Dio client: `parseSseEvents` turns the byte stream into typed `SseProgress`/`SseDone`/`SseError` events, and `openSse` wires it through the existing Bearer/401 Dio setup with request cancellation tied to subscription cancellation. The implementation is careful — chunk-boundary accumulation without normalization, cancellation before and after the response arrives, pause/resume propagation including the paused-before-response window — and the tests cover the claimed cases with canned byte streams only (no network, no timing races). I could not confirm a single defect: every candidate issue investigated was refuted by experiment or by reading the backend. The only divergences from the TypeScript original are intentional, documented in the PR body and `docs/FLUTTER.md`, and unreachable against this backend.

## Findings

None.

## Checked and fine

- Wire format vs backend: `routes/sse.py` emits exactly `progress`/`done`/`error`; Litestar's `ServerSentEventMessage.encode()` writes `event: X\r\ndata: Y\r\n\r\n` (`DEFAULT_SEPARATOR = "\r\n"`, confirmed in the installed litestar source) — matches the parser's `\r\n\r\n|\n\n` boundaries and the test's recorded sample. Error payloads are plain text already sanitized by `sse.py` (domain messages or generic `failure_message`), so no SQL/driver detail can leak through `SseError`
- Parser: split chunks (1–16 and 4096 byte tests, plus a separator split across chunks), split multi-byte UTF-8 (the `utf8.decoder` reassembly), LF and CRLF, field values with and without the trailing space, multi-line `data:` joined with `\n`, comments, unknown/missing event names, empty messages — all handled; verified experimentally that Dart's decoder strips a leading BOM exactly like the TS `TextDecoder`, so no parity gap there
- Terminal handling: the stream ends after the first `done`/`error`; `SseStreamEndedException` when the bytes end without one; a malformed progress/done payload throws `SseFormatException` instead of a raw decode error — deliberate hardening (commit e8f3ecc) with a test matrix covering invalid JSON, wrong types, missing fields
- Resource handling: cancel before the response arrives is proven by a test (the adapter's `cancelFuture` fires); cancel mid-stream goes through `events.cancel()` + `cancelToken.cancel()`; the cancel-induced Dio error is swallowed; pause/resume propagates to the parse subscription, including the window where the consumer paused before the response arrived (`connect()`'s `isPaused` check); after an error event the controller receives both `addError` and `close` (verified experimentally — the consumer's `await for`/`toList` cannot hang); a non-2xx status surfaces as a `DioException`, and a 401 flows through the `createApiDio` interceptor as documented (checked against `app/lib/api/api_client.dart`)
- Parity with `frontend/src/lib/api/sseStream.ts`: the differences are intentional and documented — (1) Dart ends at the first terminal event while TS keeps draining (and would prefer a later `error` over an earlier `done`; the backend never sends anything after a terminal event — `sse.py` puts the `None` sentinel immediately after `done`/`error`), (2) Dart validates `processed`/`total` as integers instead of blind-casting, (3) Dart accepts `event:`/`data:` without the space TS requires. One Dart-side robustness gain: it resolves immediately on the terminal event even if the server never closes the connection, where TS would hang waiting for stream end. No TS test suite exists for `sseStream.ts`, so no ported-test cases are missing
- Tests: all canned (no flakiness by construction); the pre-response cancel test polls a condition with 1 ms delays instead of racing a clock; POST method, path and `Accept: text/event-stream` header asserted
- CLAUDE.md compliance: only `///` doc comments (no narrative comments); no dead code (`parseSseEvents` is used by `openSse` and the tests); `docs/FLUTTER.md`'s new paragraph is accurate to the code; no backend/Bruno/Taskfile changes were owed by this PR
- Known shared limitation, not a regression: if a server never sent a message boundary, the buffer would grow unbounded — identical in the TS reader, and the source is the app's own authenticated backend
- `openSse` has no production caller yet — that matches the issue's scope (the sync/import screens arrive with #268/#276); flagged here so it is a conscious acceptance, not an oversight

## Open questions

None.
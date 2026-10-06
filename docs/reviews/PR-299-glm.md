# Review of PR #299: feat(app): configurable backend URL

- Reviewer: GLM
- Branch: `251-backend-url`, commit reviewed: 27519fc
- Issue: #251
- Checks run: `task app:lint` (pass), `task app:test` (pass, 48 tests), `task app:format:check` (pass) — all in the branch's worktree at commit 27519fc. Standalone Dart probes (outside the worktree) probed `Uri.tryParse` for out-of-range ports, non-ASCII hosts, userinfo and host case-folding; the probe results back findings 1 and 2 below.

## Summary

The PR makes the backend address configurable in the Flutter client: `parseServerUrl` validates a user- or build-supplied URL (`https` for any host, `http` only for loopback, no query/fragment, whitespace and trailing slashes trimmed), `resolveDefaultServerUrl` resolves the build-time `API_URL` define with a debug-only `http://localhost:8000` fallback, `checkServerHealth` probes `GET /health` with 8-second timeouts, `ServerUrlStore` persists the choice, and `changeServer` orchestrates validate → health check → clean-up callback → save, keeping the old server when the clean-up throws. The design is sound: the security rule (no cleartext Bearer token off-loopback) is enforced at the boundary, the health check runs before anything is saved, and the ordering guarantees (clean-up finishes before the new URL is stored; a failed clean-up leaves the old server) are each pinned by a test. The findings are two edge cases of Dart's `Uri` parsing that `parseServerUrl` lets through — out-of-range ports and non-ASCII hosts — where the user only learns "could not reach the server" instead of "invalid address".

## Findings

### `parseServerUrl` accepts out-of-range ports (minor, confirmed)
- Location: `app/lib/api/server_url.dart:33-55`
- Problem: Dart's `Uri.tryParse` parses a port but does not validate its range (a real validator would reject anything outside 0–65535; port 0 is not a usable client port either). A URL like `https://api.example.com:99999` passes validation, passes the health check stage only to fail at the socket layer, and the user gets the generic "Could not reach the server. Check the address and your connection." instead of the precise "invalid address" message the validator exists to give. CLAUDE.md's "validate at boundaries" rule is met for scheme and transport security but not for the port component.
- Evidence: probe — `Uri.tryParse('https://api.example.com:99999')` succeeds with `port=99999`; `Uri.tryParse('https://api.example.com:0')` succeeds with `port=0`. No test in `app/test/api/server_url_test.dart` pins either input (the `parseServerUrl` group covers scheme, loopback, protocol, blank-ish values, trimming, path prefix, query/fragment).
- Suggested fix: add `if (uri.hasPort && (uri.port < 1 || uri.port > 65535))` → `ServerUrlInvalid` (the existing "Enter a full server address…" message fits), and pin `https://api.example.com:99999` in the rejects group. Note Dart's `uri.port` returns the *scheme default* (443/80) when the URL has no explicit port, so gate the check on `uri.hasPort`.

### Non-ASCII hostnames pass validation but can never connect (minor, confirmed)
- Location: `app/lib/api/server_url.dart:33-55`
- Problem: Dart's `Uri` percent-encodes a non-ASCII host instead of converting it to punycode, so `https://exämple.com` validates with host `ex%C3%A4mple.com` — an address no HTTP client can resolve. (The WHATWG `URL` the web ecosystem uses performs IDNA/punycode conversion, so the same input behaves differently across the project's two client stacks.) The user types a plausible address, it is accepted, and the failure again surfaces only as the generic health-check message. A related parsing quirk: `https://api.example.com:@8000` parses with `host=8000` (Dart treats `api.example.com:@` as userinfo), so a typo'd URL can silently validate against the wrong host.
- Evidence: probe — `Uri.tryParse('https://exämple.com').host` → `ex%C3%A4mple.com` (no punycode, no error); `Uri.tryParse('https://xn--exmple-cua.com').host` → `xn--exmple-cua.com` (an explicit punycode URL works fine and should keep working). No test covers non-ASCII input.
- Suggested fix: decide the policy and pin it — either reject non-ASCII hosts (`uri.host.codeUnits.any((c) => c > 0x7f)` → invalid, telling users to paste the punycode form), or normalize via punycode conversion before storing. Rejecting is the smaller change and matches the "validate at boundaries" rule; a test with `https://exämple.com` pins the chosen direction.

## Checked and fine

- Security rule enforced at the boundary: `https` for any host, `http` only for `{localhost, 127.0.0.1, ::1}`, every other scheme rejected with a message that explains *why* (cleartext sign-in); tested for all three loopback hosts
- Empty-host hole closed: `uri.host.isEmpty` rejects `https://` and `https://?q=1` — exactly the divergence reported for `safe_url.dart` in PR #298 does *not* exist here
- Host case-folding: `http://LOCALHOST:8000` validates as loopback (Dart lowercases the host; probe-confirmed), so the exemption is not case-sensitive-broken
- Trimming and trailing-slash stripping (`trim()` + `replaceAll(RegExp(r'/+$'), '')`), path prefixes kept, query and fragment rejected — each pinned by a test
- `resolveDefaultServerUrl`: build define wins over the debug fallback, invalid defines are ignored (validated through the same `parseServerUrl`, not trusted), a release build without a define has *no* default so the user must enter one — all three pinned
- `checkServerHealth`: `GET /health` on the candidate server, 8 s connect/receive timeouts, non-2xx → "The server answered with an error (<status>)", unreachable → the generic message, `dio.close()` in `finally` so no dangling client; injectable `HttpClientAdapter` keeps the tests canned
- `ServerUrlStore`: `SharedPreferences`-backed with the default as fallback; null without either — pinned
- `changeServer` ordering: invalid URL → no save, no sign-out; unhealthy server → no save, no sign-out; URL change → `onChanged` completes *before* the new URL is written (pinned by a test that finishes the clean-up before the save); a throwing `onChanged` keeps the old server (nothing was written yet); an unchanged URL does not sign the user out — all pinned
- No production caller yet (`changeServer`/`ServerUrlStore` are referenced only by their tests): matches the issue's scope — the sign-in screen that uses them is #256. Flagging it here so it is a conscious acceptance, same as `openSse` in #297
- CLAUDE.md compliance: only `///` doc comments, no dead code beyond the staging noted above, no config/narrative comments; `String.fromEnvironment` is the correct mechanism for the `--dart-define=API_URL` build value (the define in a release build without it is an empty string, which the code handles via `define.isEmpty`)

## Open questions

- `https://user:pw@api.example.com` validates and would be stored with the credentials embedded (Dio does not send userinfo from the base URL, so it is inert — but the string sits in `SharedPreferences`). Acceptable, or should `uri.userInfo` be rejected the way query and fragment are?
- Should the loopback set include `[::1]`-bracket forms or link-local names like `*.local`? Current scope matches the issue text; only raising it because mDNS-style addresses (`http://homeserver.local:8000`) are a plausible desktop-app deployment that the rule forces onto https.
# Backend security

What protects the backend and how the dependency audit is set up. See
[ARCHITECTURE.md](ARCHITECTURE.md) for why auth is REST + JWT.

## What the backend enforces

| Concern | Mechanism |
|---|---|
| Passwords | Argon2; 12-128 characters, checked on account creation and every password change |
| Usernames and e-mails | Set only as a 3-32 character username of `A-Z a-z 0-9 _ - .` and an e-mail with one `@` and a dotted domain, at most 255 characters (`schemas/types.py`); anything else is a 400. Lookups (space invitation) only require 1-50 characters, so names from before this rule stay reachable |
| Input sanitizing | Every JSON body is sanitized before it is validated (`sanitize.py`, the app's `request_class`): NFC normalization, invisible formatting characters (bidi overrides and isolates, directional marks, zero-width spaces, word joiners, byte order marks) and control characters other than tab and line breaks removed, edges trimmed. Values of `password` keys are left exactly as typed. The Flutter app applies the same cleanup (without NFC) to every JSON body in its Dio interceptor |
| SQL injection | Every query goes through SQLAlchemy with bound parameters, `text()` only holds constant SQL. `tests/test_sql_injection.py` sends classic payloads to the login, the username lookup and the space invitation |
| Brute force | Login and 2FA verify: 10 requests/minute per client IP. Per account: 5 failed attempts (wrong password or wrong 2FA code) lock the account for 15 minutes, answering with the same generic error as any bad login |
| Client IP behind a proxy | The rate limit keys on `CF-Connecting-IP`, believed only when the socket peer is inside `TRUSTED_PROXY_IPS`. Without it every user would share the proxy's bucket |
| Session revocation | Access tokens carry the user's `TokenVersion`. It is bumped on every password change, on disabling 2FA and by `POST /api/auth/logout-all`; older tokens then get 401. Tokens issued before this existed carry no version and count as version 0 |
| Token lifetime | 30 days; revocation (above) is the safety net rather than a short lifetime |
| Request size | 10 MiB body limit (413 above it) |
| Response headers | `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Strict-Transport-Security` on every response; `Cache-Control: no-store` on login responses |
| API docs | `/schema` is only served with `ENABLE_DOCS=true` |
| Secrets | Startup fails for an `AUTH_SECRET` shorter than 32 characters or still set to the `.env.example` placeholder, and for invalid Fernet keys |
| Admin routes | Every `/api/admin/*` route is covered by a test that a non-admin gets 403 |

A lockout can be triggered by anyone who knows an account's email, so the
account can be kept locked out for as long as they keep guessing. That was
judged preferable to leaving password guessing per account unbounded.

Sanitizing only removes what is never legitimate text: invisible
characters that can disguise a name or reorder what is displayed (Trojan
Source style), and stray control characters. Punctuation such as `'`, `;`
or `{}` is never stripped: with bound parameters that adds no protection,
and it would silently change legitimate data (game titles like
"Assassin's Creed", reviews, passwords). What still does not fit a rule
(a username or e-mail address) is rejected with a 400, not rewritten.

## Dependency audit

`task audit` scans the locked dependencies for known vulnerabilities.

- Backend: it deliberately ignores PYSEC-2026-1325 (`ecdsa`, pulled in by
  `python-jose`, no fixed release): tokens are signed with HS256, so the ECDSA
  code path is never reached. Revisit if `python-jose` is replaced or the
  signing algorithm changes.

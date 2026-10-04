# Backend security

What protects the backend and how the dependency audit is set up. See
[ARCHITECTURE.md](ARCHITECTURE.md) for why auth is REST + JWT.

## What the backend enforces

| Concern | Mechanism |
|---|---|
| Passwords | Argon2; 12-128 characters, checked on account creation and every password change |
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

## Dependency audit

`task audit` scans the locked dependencies for known vulnerabilities.

- Backend: it deliberately ignores PYSEC-2026-1325 (`ecdsa`, pulled in by
  `python-jose`, no fixed release): tokens are signed with HS256, so the ECDSA
  code path is never reached. Revisit if `python-jose` is replaced or the
  signing algorithm changes.
- Frontend: `task frontend:audit` covers production dependencies only, and CI
  runs the same `npm audit --omit=dev`, so a new advisory against anything that
  ships fails the pull request. `npm audit` on the full tree still reports
  `braces` (GHSA-vfj7-8cjw-p6xm, reached through `eslint-config-next` ->
  `fast-glob` -> `micromatch`, ESLint tooling that never ships): every released
  version is affected and no patched release exists, so nothing can be
  upgraded. Because that finding cannot be acted on, `frontend/.npmrc` sets
  `audit=false` to keep it from showing up as noise after every
  `npm install`; run `npm audit` explicitly to see it, and recheck when
  `braces` publishes a fix.

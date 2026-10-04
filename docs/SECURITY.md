# Backend security

The backend is the only publicly hosted piece (`blm.theocloud.dev`, behind a
Cloudflare tunnel) and is used by two people. This page records what protects
it and what to check before a deployment. See [ARCHITECTURE.md](ARCHITECTURE.md)
for why auth is REST + JWT.

## What the backend enforces

| Concern | Mechanism |
|---|---|
| Passwords | Argon2; 12-128 characters, checked on account creation and every password change |
| Brute force | Login and 2FA verify: 10 requests/minute per client IP. Per account: 5 failed attempts (wrong password or wrong 2FA code) lock the account for 15 minutes, answering with the same generic error as any bad login |
| Client IP behind the proxy | The rate limit keys on `CF-Connecting-IP`, believed only when the socket peer is inside `TRUSTED_PROXY_IPS`. Without it every user would share the proxy's bucket |
| Session revocation | Access tokens carry the user's `TokenVersion`. It is bumped on every password change, on disabling 2FA and by `POST /api/auth/logout-all`; older tokens then get 401. Tokens issued before this existed carry no version and count as version 0 |
| Token lifetime | 30 days; revocation (above) is the safety net rather than a short lifetime |
| Request size | 10 MiB body limit (413 above it) |
| Response headers | `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Strict-Transport-Security` on every response; `Cache-Control: no-store` on login responses |
| API docs | `/schema` is only served with `ENABLE_DOCS=true` |
| Secrets | Startup fails for an `AUTH_SECRET` shorter than 32 characters or still set to the `.env.example` placeholder, and for invalid Fernet keys |
| Admin routes | Every `/api/admin/*` route is covered by a test that a non-admin gets 403 |

A lockout can be triggered by anyone who knows an account's email, so the
account can be kept locked out for as long as they keep guessing. With two
users and Cloudflare's own rate limiting in front, that was judged
preferable to leaving password guessing per account unbounded.

## Deployment checklist

- `AUTH_SECRET`: `openssl rand -base64 32`; `TOTP_ENCRYPTION_KEY` and
  `STEAM_API_KEY_ENCRYPTION_KEY`: a Fernet key (see `.env.example`).
- `TRUSTED_PROXY_IPS` set to the cloudflared network, so the rate limit sees
  real client IPs.
- `ENABLE_DOCS=false`.
- Postgres and pgAdmin are published on `127.0.0.1` only by `compose.yml`;
  do not expose them. Change `PGADMIN_DEFAULT_PASSWORD` and
  `POSTGRES_PASSWORD` from the `.env.example` values.
- `CORS_ALLOWED_ORIGINS` lists only the origins that actually call the API.
- Cloudflare: keep the WAF/bot protection on, and add a rate-limiting rule
  for `/api/auth/*` as a second layer in front of the backend's own.
- `task audit` for known-vulnerable dependencies. It deliberately ignores
  PYSEC-2026-1325 (`ecdsa`, pulled in by `python-jose`, no fixed release):
  tokens are signed with HS256, so the ECDSA code path is never reached.
  Revisit if `python-jose` is replaced or the signing algorithm changes.
  `task frontend:audit` covers production dependencies only (currently
  clean), and CI runs the same `npm audit --omit=dev`, so a new advisory
  against anything that ships fails the pull request.
  `npm audit` on the full tree still reports `braces` (GHSA-vfj7-8cjw-p6xm,
  reached through `eslint-config-next` -> `fast-glob` -> `micromatch`, ESLint
  tooling that never ships): every released version is affected and no
  patched release exists, so nothing can be upgraded. Because that finding
  cannot be acted on, `frontend/.npmrc` sets `audit=false` to keep it from
  showing up as noise after every `npm install`; run `npm audit` explicitly to
  see it, and recheck when `braces` publishes a fix.
- Node: the frontend runs on Node 22 (22.12+), pinned in `.nvmrc`, the
  Containerfile and the workflows. Node 20 reached end of life in April 2026,
  and other versions such as 23.x fail with cryptic webpack errors, so
  `engine-strict` makes `npm install` reject them and `next.config.js` aborts
  early with a clear message. Moving to a newer LTS means updating those pins
  together with `SUPPORTED_NODE_MAJORS` and `engines`, and checking the
  build.

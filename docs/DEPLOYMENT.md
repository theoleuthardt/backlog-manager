# Production deployment

How the backend runs in production (`blm.theocloud.dev`): a Docker/Podman
Compose stack on a server (a Proxmox LXC, managed with Dockhand), reached
through a Cloudflare Tunnel. Files involved:

| File | Purpose |
|---|---|
| [`compose.prod.yml`](../compose.prod.yml) | database, migration job, backend and price-check cron; pulls the published backend image |
| [`.env.prod.example`](../.env.prod.example) | every setting the stack needs, with how to generate each secret |
| [`postgres/backlogmanagerdb-init.sql`](../postgres/backlogmanagerdb-init.sql) | schema for a fresh database |

The local development stack stays in `compose.yml` (see the README); this page
is only about production. The security background of the settings is in
[`SECURITY.md`](SECURITY.md).

```
Desktop app (Tauri) --HTTPS--> Cloudflare --tunnel--> cloudflared --HTTP--> <server-ip>:8000 (backend)
                                                                                   |
                                                                       db (Postgres, internal only)
                                                                       price-check-cron (internal only)
```

Only the backend is public. The frontend ships as the Tauri desktop app, so
there is no frontend container and no pgAdmin on the server. TLS ends at
Cloudflare; between cloudflared and the backend the traffic is plain HTTP.

## What the compose file does

- `db` - Postgres 17, data in the `postgres_data` volume, not published to the
  host. On the very first start it runs the init SQL (mounted into
  `docker-entrypoint-initdb.d`; ignored once the volume exists).
- `migrate` - a one-shot job that runs before the backend. On a fresh database
  (no Alembic version yet) it first stamps the current head, because the init
  SQL already contains every migration; otherwise it runs
  `alembic upgrade head`. Updates therefore migrate automatically.
- `backend` - the API, published on `BACKEND_BIND_ADDRESS:BACKEND_PORT`.
- `price-check-cron` - calls the price sweep every 6 hours with the shared
  secret.

The backend image is `ghcr.io/theoleuthardt/backlog-manager-backend`: public
(no registry login), `linux/amd64` only, tagged `:latest` and `:<commit sha>`
by the *Build & Publish* workflow on every push to `main`. The backup
scheduler runs inside the API process and assumes a single worker, which is
what the image's plain `uvicorn` command gives; do not add `--workers`.

## 1. Cloudflare Tunnel

In the Zero Trust dashboard (labels differ slightly between versions):

1. **Networks -> Tunnels.** Reuse the tunnel your existing cloudflared runs on,
   or create one (type *Cloudflared*) and install the connector with the shown
   command on the machine that can reach the backend.
2. Add a **Public hostname** (newer dashboards: *Published applications*):
   subdomain `blm`, domain `theocloud.dev`, empty path, service type **HTTP**
   (the backend speaks plain HTTP), URL `<server-lan-ip>:8000` - or
   `localhost:8000` when cloudflared runs on the same machine as the backend.
3. Cloudflare creates the proxied `blm` CNAME itself; delete an existing `blm`
   DNS record first.
4. Do not put Cloudflare Access (a login page) in front of the API: the desktop
   app cannot pass it and already authenticates with JWT and optional 2FA.
   Avoid *Bot Fight Mode* / *Under Attack* for this hostname too, a challenge
   page instead of JSON breaks the app's API calls.
5. Recommended second layer: **Security -> WAF -> Rate limiting rules**, a rule
   for URI paths starting with `/api/auth/` (for example 20 requests per 10
   seconds per IP, action Block). The backend's own limits sit behind it: 10
   login attempts per minute per client IP, and five failed attempts lock an
   account for 15 minutes.

## 2. Server

Docker with Compose v2 (Dockhand/Hawser implies it); the commands below use
`docker compose`, with Podman use `podman compose`. If cloudflared runs on
another machine, the backend port must be reachable from it; set
`BACKEND_BIND_ADDRESS` to the server's LAN IP so the port is not open on every
interface (`127.0.0.1` when cloudflared runs on the same machine).

Pin one commit for the first install. The init SQL creates the schema of
exactly one version and the image stamps its own migration head on a fresh
database, so both must come from the same commit:

```bash
SHA=$(git ls-remote https://github.com/theoleuthardt/backlog-manager main | cut -f1)
RAW="https://raw.githubusercontent.com/theoleuthardt/backlog-manager/${SHA}"
mkdir -p /opt/backlog-manager/postgres && cd /opt/backlog-manager
curl -fsSL -o compose.yml "${RAW}/compose.prod.yml"
curl -fsSL -o .env "${RAW}/.env.prod.example"
curl -fsSL -o postgres/backlogmanagerdb-init.sql "${RAW}/postgres/backlogmanagerdb-init.sql"
chmod 600 .env
echo "${SHA}"
```

If the `:<sha>` image tag of that commit does not exist yet, wait for the
*Build & Publish* run.

Fill in `.env` (every `<...>` value; the file explains how to generate each
secret) and set `BACKEND_IMAGE=ghcr.io/theoleuthardt/backlog-manager-backend:<SHA>`.
Leave `TRUSTED_PROXY_IPS` empty for now.

## 3. First start

```bash
docker compose up -d
docker compose ps                 # db healthy, migrate "Exited (0)", backend and price-check-cron Up
docker compose logs migrate       # "Running stamp_revision -> <head>" on a fresh database
docker compose logs backend       # "Created initial admin user", "Application startup complete"
curl -s http://<server-ip>:8000/health    # {"status":"ok","database":"connected"}
```

Once the admin exists, empty `INITIAL_ADMIN_EMAIL` and `INITIAL_ADMIN_PASSWORD`
in `.env`: they are ignored from then on and the password should not stay in
the file.

## 4. Trusted proxy

The login rate limit keys on the client IP. Behind Cloudflare every request
arrives from cloudflared, so without this setting all users share one bucket,
and one person hitting the limit locks everyone out. The backend reads the real
IP from `CF-Connecting-IP`, but only believes that header when the direct peer
is inside `TRUSTED_PROXY_IPS`.

1. Make one request through the tunnel: `curl -i https://blm.theocloud.dev/health`.
2. Read the peer the backend saw:
   `docker compose logs backend | grep "GET /health" | tail -3`. The address
   before the colon in `10.0.0.5:51234 - "GET /health ...` is what cloudflared
   connects from.
3. Put exactly that address into `.env`, for example
   `TRUSTED_PROXY_IPS=10.0.0.5/32` (the subnet if the address can change).
   Keep it narrow, never `0.0.0.0/0`.
4. Apply it with `docker compose up -d`. With **podman-compose** a changed
   `.env` is not picked up by `up -d` or `up -d --force-recreate <service>`;
   run `podman compose down && podman compose up -d` (the data lives in the
   volume and survives).
5. Verify from your own network: 11 wrong logins, the 11th must return 429,
   while a login from a different network (a phone hotspot) must still return
   a normal 401 for a wrong password:

   ```bash
   for i in $(seq 1 11); do curl -s -o /dev/null -w "%{http_code} " \
     -X POST https://blm.theocloud.dev/api/auth/login \
     -H 'Content-Type: application/json' \
     -d '{"email":"nobody@example.com","password":"x"}'; done; echo
   ```

   If the other network gets 429 as well, the header is not trusted: re-check
   steps 2 and 3.

## 5. Check from outside

- `curl -i https://blm.theocloud.dev/health` returns 200 and the JSON above.
- `https://blm.theocloud.dev/schema` returns 404 (docs are off).
- `curl -sI https://blm.theocloud.dev/health` shows the security headers.
- The GitHub Actions repository variable `NEXT_PUBLIC_API_URL` must be
  `https://blm.theocloud.dev` before building the desktop app (it is baked in
  at build time).
- If the app reports a CORS error, add the origin from the message to
  `CORS_ALLOWED_ORIGINS` and restart as in step 4.4. The defaults in
  `.env.prod.example` are Tauri v2's origins (`tauri://localhost` on
  macOS/Linux, `http://tauri.localhost` on Windows).

## 6. First accounts with Bruno

1. Fill the Prod environment (`bruno/environments/Prod.bru`, a local file):
   `backendUrl = https://blm.theocloud.dev`.
2. Run `auth/Login` with the admin account; it stores the token in `authToken`.
3. Create further accounts with `admin/Create User` (password 12-128
   characters).
4. Reset any user's password with `admin/Update User` and
   `{ "password": "<new password>" }`; that invalidates the user's existing
   sessions. `auth/Logout All Sessions` does the same for yourself.
5. Turn on two-factor authentication for the admin account in the app
   (Account -> Two-Factor Authentication).

## 7. Updates

- After the first install switch `BACKEND_IMAGE` from the pinned `:<sha>` to
  `ghcr.io/theoleuthardt/backlog-manager-backend:latest`, so pulling picks up
  new builds. The init SQL is only used on an empty database and never needs
  updating afterwards.
- Every update has to run the `migrate` job before the new backend starts. That
  happens when the whole stack is redeployed
  (`docker compose pull && docker compose up -d`). If Dockhand only recreates
  the `backend` container, run `docker compose run --rm migrate` after updates
  that add migrations, otherwise the backend runs against an old schema.
- Roll back by pinning `BACKEND_IMAGE` to the previous `:<sha>`. Migrations only
  go forward, so dump the database first:

  ```bash
  docker compose exec -T db pg_dump -U blm backlog-manager-db | gzip > blm-$(date +%F).sql.gz
  ```

- The daily Proxmox backup covers the whole server; the app's own per-user
  backups (Account -> Backups, see [`BACKUPS.md`](BACKUPS.md)) are an additional
  safety net for backlog data only.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Backend exits right after start | `docker compose logs backend` names the setting: an `AUTH_SECRET` shorter than 32 characters or a placeholder, an invalid Fernet key, an invalid `TRUSTED_PROXY_IPS` entry. |
| `migrate` fails on a fresh install | Init SQL and image are from different commits, or an old `postgres_data` volume exists. Start over with `docker compose down -v` (deletes the database) and use one pinned SHA for both. |
| Everyone gets 429 on login | `TRUSTED_PROXY_IPS` does not contain the address cloudflared connects from (step 4). |
| CORS error in the app | Add the origin from the error message to `CORS_ALLOWED_ORIGINS`, then restart as in step 4.4. |
| `manifest unknown` / `no matching manifest` on pull | The `:<sha>` tag is not published yet, or the host is not `amd64`. |
| `.env` change has no effect (podman-compose) | `down && up -d`, not only `up -d` (step 4.4). |
| 502 from Cloudflare | cloudflared cannot reach `<server-ip>:8000`: check `BACKEND_BIND_ADDRESS`, the firewall and that the service type is HTTP, not HTTPS. |

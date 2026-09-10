# Game Price Tracking (Issue #102)

## Context

Issue #102 asks for three things: current price across Steam/GOG/retailers, all-time-low price, and a sale-alert system. Research before implementing surfaced two facts that reshape scope:

- **SteamDB has no public API** (its ToS explicitly disallows scraping/unofficial API use), so "all-time low from SteamDB" isn't buildable on a legitimate API. **CheapShark's own `/games?id=` endpoint already returns a `cheapestPriceEver` field**, which covers the all-time-low requirement without SteamDB.
- **The backend has no background job/scheduler at all** — everything today is on-demand HTTP. A real periodic price-check needs a new externally-triggered endpoint (e.g. a scheduled GitHub Actions workflow hitting the backend), not a new in-process scheduler.

Scoping decisions made with the repo owner:
- Scope = price display (current + all-time-low) **and** a lightweight alert mechanism (not full job-scheduler infra).
- "Alert system" means **a Discord webhook message**, not an in-app notification.
- The Discord webhook is **per-user, set in Account settings**, falling back to a server-wide `DISCORD_WEBHOOK_URL` env var for users who haven't set their own — the same per-user-credential-with-server-wide-fallback pattern as the Steam/IGDB/SteamGridDB keys.

CheapShark (`https://www.cheapshark.com/api/1.0/`) needs no API key. Relevant endpoints: `GET /games?steamAppID=<id>` (resolve CheapShark's internal `gameID` for a Steam App ID) and `GET /games?id=<gameID>` (per-store `deals` with `price`/`retailPrice`/`savings`, plus `cheapestPriceEver`).

## Backend design

**New integration** — `backend/src/backlog_manager_backend/integrations/cheapshark.py`, following the shape of `integrations/steamgriddb.py` (fresh `httpx.AsyncClient` per call, `msgspec.json.decode`, raise on transport/HTTP/decode error since this isn't a best-effort enrichment step):
- `find_cheapshark_game_id(steam_app_id: int) -> int | None` — `GET /games?steamAppID=`, returns the first match's `gameID` (CheapShark returns this as a numeric string in JSON — modeled as `str` and parsed with `int()`).
- `get_cheapshark_game_detail(cheapshark_game_id: int) -> CheapSharkGameDetail` — `GET /games?id=`, decodes `deals` (list of `{storeID, price, retailPrice, savings}`) and `cheapestPriceEver` (`{price, date}`).
- `get_stores() -> list[CheapSharkStore]` — `GET /stores`, for mapping `storeID` → display name (`storeID`, `storeName`, `isActive`).

New msgspec structs live in `integrations/types.py` alongside the existing `SteamGridDB*`/`IGDB*` structs: `CheapSharkDeal`, `CheapSharkPriceEver`, `CheapSharkGameInfo`, `CheapSharkGameDetail`, `CheapSharkStore`, `CheapSharkGameLookup`.

**New Discord integration** — `backend/src/backlog_manager_backend/integrations/discord.py`:
- `send_discord_webhook_message(webhook_url: str, content: str) -> None` — plain `httpx.AsyncClient().post(webhook_url, json={"content": content})`. Best-effort: catches `httpx.HTTPError`, logs via `structlog`, swallows (mirrors `_try_get_steamgriddb_covers`'s best-effort convention) — a Discord outage must not break the price sweep.

**Per-user Discord webhook** — a new `User.discord_webhook_url_encrypted` column (Fernet-encrypted, same shared key as the Steam/SteamGridDB columns), wired through `schemas/user.py`, `repositories/user_repo.py` and `routes/user.py` exactly like `steamgriddb_api_key` (reuses the existing `_encrypt_api_key_if_present` helper). Resolution (`price_service._resolve_discord_webhook_url`) checks the user's own decrypted webhook first, falling back to `settings.discord_webhook_url`.

**New models + migrations**, both under `schema="blm-system"`:
- `models/game_price.py` — `GamePrice`, one row per tracked `steam_app_id` (shared cache across all users, since the CheapShark data itself doesn't vary by who's tracking it):
  ```
  SteamAppId            BigInteger, PK
  CheapsharkGameId      BigInteger, nullable   -- cached steamAppID -> CheapShark gameID mapping
  Deals                 JSON, nullable          -- [{"store": "Steam", "price": 9.99, "retail_price": 19.99}, ...]
  CheapestPriceEver     Numeric(10,2), nullable
  CheapestPriceEverDate Date, nullable
  OnSale                Boolean, server_default false
  CheckedAt             Timestamp, not null
  ```
- `models/user_game_price_alert.py` — `UserGamePriceAlert`, per-**user** alert-dedup state (composite PK `UserID`+`SteamAppId`, FK to `Users` with cascade delete):
  ```
  UserID           BigInteger, PK, FK -> Users
  SteamAppId       BigInteger, PK
  LastAlertedPrice Numeric(10,2), not null
  UpdatedAt        Timestamp, server_default
  ```
  This has to be per-user, not shared on `GamePrice`, because two users tracking the same game can have different Discord webhooks and must each be notified independently — a global "already alerted" flag would silently skip the second user.

These are the first two Alembic migrations in the repo that `create_table` rather than `add_column`/`drop_column` (all prior ones only touched existing columns) — written by hand after autogenerate, since autogenerate also picks up unrelated pre-existing schema drift between the SQLAlchemy models and the baselined DB that has nothing to do with this change.

**New repositories**:
- `repositories/game_price_repo.py`: `get_game_price`, `upsert_game_price`, `get_tracked_user_steam_app_id_pairs(session, *, owned=None) -> list[tuple[int, int]]` (distinct `(UserID, SteamAppId)` pairs from `BacklogEntries`, `owned=False` for the sweep), `get_title_for_steam_app_id`.
- `repositories/user_game_price_alert_repo.py`: `get_last_alerted_price`, `set_last_alerted_price` (upsert).

**New service** — `services/price_service.py`, following `game_service.py`'s style:
- `_STALE_AFTER_SECONDS = 3600` (1 hour).
- `_store_names` in-memory cache (unbounded, no TTL — same convention as `_genre_cache`/`_platform_cache`), populated lazily from `get_stores()`.
- `get_price_info(session, steam_app_id) -> GamePrice` — on-demand path: returns the cached row if `CheckedAt` is fresh, otherwise refreshes from CheapShark, computes `OnSale` (any deal with `savings > 0`), upserts, and returns.
- `check_prices_and_alert(session) -> int` — the sweep: fetches every distinct `(user_id, steam_app_id)` pair with `owned=False`, refreshes each distinct `steam_app_id`'s price once, then for each pair whose price is on sale: resolves that user's Discord webhook, skips if it hasn't changed since `UserGamePriceAlert.LastAlertedPrice`, otherwise sends one Discord message and updates the dedup row. Returns the alert count.

**New routes**:
- `GET /api/games/{steam_app_id:int}/price` — added to `routes/games.py`'s `authenticated_games_router` (JWT-protected; keeps an unused `current_user` parameter since the router's auth dependency only runs for handlers that declare it — see the existing `admin_user_router` comment for the same gotcha). Returns `GamePrice` via `price_service.get_price_info`.
- `POST /api/prices/check` — new `backend/src/backlog_manager_backend/routes/prices.py`. Not JWT-protected — this is the repo's only machine-to-machine endpoint, meant for an external scheduler rather than a logged-in user. Gated by a static shared-secret header (`X-Cron-Secret`, compared with `secrets.compare_digest` against `settings.price_check_cron_secret`). Registered as `price_check_router` in `app.py`.

**Config** (`config.py`): `discord_webhook_url: str | None` (server-wide fallback, same pattern as `steam_web_api_key`) and `price_check_cron_secret: str | None` (global/ops-only, gates the cron endpoint). Both added to `.env.example`.

## Frontend design

- `frontend/src/lib/api/games.ts`: `getGamePrice(steamAppId)` calling `GET /api/games/{steam_app_id}/price`, mapping snake_case → camelCase.
- `frontend/src/hooks/useGameSearch.ts`: `useGamePrice(steamAppId, enabled = true)`, a `useQuery` mirroring `useSteamAchievements`'s default-enabled style — since it's mounted inside `BacklogEntry`'s `DialogContent`, which Radix unmounts when the dialog is closed, mounting alone already gates the fetch to "the entry dialog is open."
- `frontend/src/app/_components/GamePriceSection.tsx`: new component (mirrors `AchievementProgress.tsx`'s loading/empty-state handling) showing each store's current price (struck-through retail price when discounted), an "on sale" line, and the all-time low. Mounted in `BacklogEntry.tsx` as a `price-section` block next to `hltb-section`/`achievements-section`.
- `frontend/src/lib/api/user.ts` / `auth.ts`: `discordWebhookUrl` on `UpdateCurrentUserInput`, `hasDiscordWebhookUrl` on `CurrentUser`.
- `frontend/src/app/_components/AccountContent.tsx`: new "Discord Price Alerts" card, mirroring the SteamGridDB API key card's set/remove UI exactly.

## Triggering the sweep

There's no in-process scheduler (see Context above), so a `price-check-cron` service in `compose.yml` runs alongside `backend` in the same Compose stack: a plain `curlimages/curl` container looping `curl -X POST http://backend:8000/api/prices/check` (container-to-container, over the Compose network) every 6 hours, using the `X-Cron-Secret` header from `PRICE_CHECK_CRON_SECRET`. Since `blm.theocloud.dev` is deployed from this same `compose.yml` (via Podman, see README's Deployment section) with `.env.prod` swapped in, this one service covers local dev and production alike — no separate scheduler infra (GitHub Actions cron, etc.) needed. `PRICE_CHECK_CRON_SECRET` (and, if a server-wide fallback webhook is wanted, `DISCORD_WEBHOOK_URL`) still need to be set in `.env`/`.env.prod` as appropriate for each environment.

## Verification

- Backend: `task test` (pytest + testcontainers, written test-first) — `test_cheapshark.py`, `test_discord.py`, `test_game_price_repo.py`, `test_price_service.py` (staleness, on-sale detection, per-user dedup, per-user webhook fallback, no-webhook no-op), `test_game_price_routes.py`, `test_prices_routes.py` (secret header enforcement).
- `task backend:migrate` locally against `task db:up`'s Postgres, confirmed to apply and roll back cleanly.
- `task lint` (ruff + eslint), `npm run typecheck`, `npm run format:check` on the touched files.
- Frontend: `task dev`, open an entry with a `steam_app_id` set and confirm the price section loads on dialog open with no request firing for entries without one; set/remove a Discord webhook URL in Account settings.
- Manually `curl -X POST /api/prices/check` locally with a real test Discord webhook and a tracked on-sale `steam_app_id` to confirm a message actually arrives end-to-end.

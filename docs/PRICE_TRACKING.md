# Game Price Tracking (Issues #102, #411)

> The Flutter app no longer shows these prices: its Prices button opens Keyforsteam in a browser window (#421, `docs/FLUTTER.md`). What is described here is still served by the backend (price route for the web client, the sweep and the Discord alerts), and `GGDEALS_API_KEY` is still what the sweep needs.

Prices come from the [GG.deals API](https://gg.deals/api/), which covers the official stores and keyshops and replaced CheapShark in #411 (CheapShark never had keyshops, and the GG.deals terms are one source to follow instead of two). Scraping is not an option: GG.deals blocks it.

## What the API gives

`GET https://api.gg.deals/v1/prices/by-steam-app-id/?ids=<id,id,...>&key=<key>` answers with `{"success": true, "data": {"<steam app id>": {"title", "url", "prices": {...}} | null}}`. `prices` has `currentRetail`, `currentKeyshops`, `historicalRetail`, `historicalKeyshops` (decimal strings, null where there is none) and `currency`; an id GG.deals does not know is `null`. The cheapest price **per channel** is all there is: no list of stores, no regular price (so no "on sale" or discount, only "at its lowest ever"). The key is a query parameter, so `integrations/ggdeals.py` never puts the URL into an error message or log line and keeps the `httpx` logger at WARNING (it prints every request URL at INFO).

Limits of a free key: 100 records per minute and 1000 per hour, every id of a request is one record, and a request over the limit is a 429 without data. Free keys are for personal, hobby and open-source use, **with an active link to GG.deals wherever the data is shown** and the `url` of a game left as it is (it carries their referral). The Flutter price sheet has the "Prices by GG.deals" link and opens the `url` unchanged.

## Keys

The key is the server's `GGDEALS_API_KEY` (`.env`) or the user's own (`Users.GgDealsApiKeyEncrypted`, Fernet like the other keys, `PUT /api/user/me` with `ggdeals_api_key`, `has_ggdeals_api_key` in the user; `services/credentials.py::resolve_ggdeals_api_key`, the user's key first). The on-demand route uses that resolution. The sweep has no user and uses the server's key only: without it nothing is refreshed (a log line says so).

## Backend

- `GamePrices` (one row per Steam App ID, shared by all users): `Currency`, `CurrentRetail`, `CurrentKeyshops`, `HistoricalRetail`, `HistoricalKeyshops`, `Url`, `CheckedAt`. A game GG.deals does not know is stored with all prices empty, so it is asked for again only when the cache runs out.
- `price_service.get_price_info(session, steam_app_id, api_key)`: serves the row while it is younger than three hours, else asks GG.deals with `api_key`. Without a key, or when GG.deals fails, an older row is still served; without any row it raises (`PriceSourceNotConfiguredError`, `httpx.HTTPError`) and `GET /api/games/{steam_app_id}/price` answers 503, so the client falls back to its search link.
- `price_service.check_prices_and_alert`: the sweep behind `POST /api/prices/check` (`X-Cron-Secret`, the `price-check-cron` container every 6 hours). It refreshes every tracked, not yet owned Steam App ID, least recently checked first, in batches of 25 ids with 20 seconds between them (75 records a minute); a 429 is waited out (`Retry-After`, 60 s without one, at most 120 s) up to twice per batch, a persistent 429 or a rejected key (401/403) stops the sweep and the rest is picked up first next time, any other error skips that batch. Then it sends one Discord message per (user, game) whose current price is **at its lowest ever** (the retail or the keyshop price is at or below its historical one, never 0), quoting the price, the channel and the GG.deals link. Dedup per user and price (`UserGamePriceAlerts`) and the per-user webhook with the server fallback are unchanged.

The old alert was "on sale" (a CheapShark deal with a saving); GG.deals does not report a regular price, so the alert is now "lowest price ever".

## Keyshop scrapers

`GET /api/games/key-shop-prices?title=` (RoyalCDKeys, PremiumCDKeys, see `docs/KEY_SHOP_SCRAPING.md`) is unchanged and is shown with the keyshops.

## Triggering the sweep

There is no in-process scheduler, so a `price-check-cron` service in `compose.yml` and `compose.prod.yml` calls `curl -X POST http://backend:8000/api/prices/check` every 6 hours with the `X-Cron-Secret` header from `PRICE_CHECK_CRON_SECRET`. For prices and alerts the `.env` of each environment needs `GGDEALS_API_KEY`, `PRICE_CHECK_CRON_SECRET` and, for a server-wide fallback webhook, `DISCORD_WEBHOOK_URL`.

## Tests

`test_ggdeals.py` (request, answer, errors, no key in messages or logs), `test_price_service.py` (cache, fallbacks, batches, pauses, rate limit, alerts), `test_game_price_repo.py`, `test_game_price_routes.py`, `test_prices_routes.py`, `test_credentials.py` and `test_user_routes.py` (the key), and in the app `price_listings_test.dart`, `price_sheet_test.dart`, `mappers_test.dart`, the settings tests.

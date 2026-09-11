# Key Shop Price Scraping (Issue #179)

## Context

Issue #179 asks for a scraper layer covering ~40 key marketplaces/resellers
not in CheapShark's official-distributor list (Eneba, G2A, Kinguin, Gamivo,
Instant Gaming, Loaded/CDKeys for Phase 1; a long tail for Phase 2), gated by
one hard constraint from the issue itself: **no bypassing bot protection, no
scraping pages requiring login, respect robots.txt**.

## What research actually found

Before writing an adapter interface, every Phase-1 shop named in the issue
was checked by hand (`curl` with a realistic browser User-Agent, checking
HTTP status, `robots.txt`, and whether pricing data is present in the
server-rendered HTML at all). Result: **none of the six Phase-1 shops named
in the issue are scrapable within the "no bot-protection bypass" constraint**:

| Shop | Finding |
|---|---|
| Eneba | Product/search pages return 200, but prices are fetched client-side after page load (Algolia + GraphQL) - nothing in the SSR HTML. Would require running a JS engine (Playwright), which is a materially bigger dependency than an `httpx` GET. |
| G2A | Every request (search, product pages, even `robots.txt`) returns HTTP 403 regardless of User-Agent - full bot-protection wall. |
| Kinguin | Cloudflare "Just a moment..." JS challenge on every page. Kinguin does have an official partner API (`dev-portal` / `purchase-api`), but it requires manual business-account approval - not something obtainable non-interactively, and appropriately out of scope for an autonomous change. |
| Gamivo | Cloudflare-blocked on every page, including the homepage. |
| Instant Gaming | Product pages themselves *are* server-rendered with a clean `itemprop="price"` meta tag and are not blocked - but the only way to resolve a game title to a product page is the `/en/search/` endpoint, which `robots.txt` explicitly disallows (`Disallow: /en/search/` and equivalents for every locale). No sitemap or other legal resolution path exists. Respecting robots.txt here means this shop isn't usable for a title→price lookup. |
| Loaded (formerly CDKeys) | Cloudflare JS challenge on every request. |

This isn't a "try harder with better headers" situation - it's Cloudflare
bot-management or client-side-only rendering on 5 of 6 sites, and a robots.txt
rule on the 6th. Working around any of these would mean either violating the
issue's own "don't force bypassing bot protection" rule or scraping a page
the site operator has explicitly disallowed for crawlers - both are avoided
here per explicit instruction to keep every scraper action legal.

**K4G specifically** (a shop the repo owner buys keys from personally,
checked in more depth on request): its storefront is a Next.js SPA
(`k4g.com`, not `www.k4g.com` - the `www` host returns a Cloudflare 520) that
loads all product data client-side via its own REST API
(`k4g.com/api/v1/en/...`, no auth, just an `x-currency` header). Network
traffic was inspected directly (temporarily installing Playwright to drive a
real browser against the live site, removed again afterward once this was
confirmed - no Playwright dependency was kept) to find the exact endpoints:
- `GET /api/v1/en/search/search?category_id=&phrase=<title>` - reachable
  and not disallowed by `robots.txt`, but does **not** actually filter by
  `phrase` (returns the same bestseller-sorted list regardless of the query
  - likely requires session/cart state the SPA sets client-side that a
  plain request doesn't have).
- `GET /api/v1/en/search/search?q=<title>` and
  `GET /api/v1/en/search/fast-search?q=<title>` - both genuinely filter by
  title and return exactly the needed price/discount/title/slug fields, but
  K4G's own `robots.txt` explicitly disallows any URL containing that query
  parameter (`Disallow: /*?q=`, `Disallow: /*&q=`) - the same "respect
  robots.txt" rule that rules out Instant Gaming applies here too, on the
  only endpoint that actually works.

**Instant Gaming**, re-checked in the same pass: product pages
(`/en/<id>-buy-<slug>/`) are cleanly server-rendered with a proper
`itemprop="price"` meta tag and aren't disallowed, but there is no legal way
to resolve a title to that product ID/slug - no sitemap, no static catalogue
page, nothing in the homepage's server-rendered HTML - only the `/en/search/`
endpoint resolves titles, and that's the one route `robots.txt` disallows.

**Loaded** (formerly CDKeys), re-checked: genuine Cloudflare JS challenge
("Just a moment...") on every request tested, including the bare domain,
`www`, and the search path directly - not a User-Agent or header quirk like
K4G's `www` redirect turned out to be.

All three (K4G, Instant Gaming, Loaded) are left unimplemented for the same
reason: the only endpoint that actually returns real, title-filtered data is
either robots.txt-disallowed or behind active bot-management, and both are
explicitly out of bounds for this change per the repo owner's instruction to
keep every scraper action legal. If any of these three sites relaxes their
`robots.txt` or ships an official partner API, adding them is one new file
under `integrations/key_shops/` (see the adapter interface below) - the
groundwork here doesn't need to change.

**What does work, legally and without any bypass:** two of the long-tail
Phase-2 shops (RoyalCDKeys, PremiumCDKeys) run on Shopify, and Shopify's
storefront ships a public, undocumented-but-standard JSON search endpoint
(`/search/suggest.json?q=<query>&resources[type]=product`) that both shops'
own `robots.txt` explicitly marks as crawlable ("Public product, collection,
page ... is crawlable"). This is not scraping in the reverse-engineering
sense - it's the same JSON endpoint Shopify's own storefront search box
calls, served without a login, without a bot challenge, and without a
robots.txt disallow. It returns exactly the fields needed: `title`, `price`,
`compare_at_price_max` (for discount detection), `handle` (product URL),
`available`.

## Scope decision

Given the above, this implementation:

- Builds the adapter interface and normalized data model the issue asks for,
  designed so any future shop (including the originally-named Phase-1 ones,
  should Kinguin's partner API get approved, or should a headless-browser
  layer be added later for JS-rendered sites) can be added as one new file.
- Ships **two working adapters** (RoyalCDKeys, PremiumCDKeys) as the actual
  Phase 1, since they're the only shops from the issue's full list (Phase 1
  + Phase 2 combined) that are both scrapable and legal without exceptions.
- Does **not** implement Eneba/G2A/Kinguin/Gamivo/Instant Gaming/Loaded
  adapters, and documents why for each, rather than stub/fake adapters that
  don't return real data or that would require violating the "no bot
  protection bypass" / "don't scrape robots.txt-disallowed pages" rules.
- Leaves the scheduling/caching/rate-limiting infrastructure the issue's
  "Technical Approach" section describes deliberately minimal (see
  `services/key_shop_price_service.py` docstring) since with only two
  low-traffic Shopify JSON endpoints there's no request-volume problem yet
  to build APScheduler/Redis infra against - the same "don't build for
  hypothetical future callers" standard this repo already applies elsewhere
  (see CLAUDE.md's Software Engineering Standards). Upgrade path noted
  inline in the code.

## Backend design

**New integration module** -
`backend/src/backlog_manager_backend/integrations/key_shops/`:
- `base.py` - `KeyShopAdapter` protocol: `shop_name: str` and
  `async def search(title: str) -> list[KeyShopOffer]`.
- `shopify.py` - one shared `_search_shopify_store(base_url, title)` helper
  (both current adapters are Shopify storefronts hitting the same
  `/search/suggest.json` shape) used by:
  - `royalcdkeys.py` - `RoyalCdKeysAdapter`
  - `premiumcdkeys.py` - `PremiumCdKeysAdapter`
- `types.py` (or `integrations/types.py`, following the existing
  cross-integration convention) - `KeyShopOffer` msgspec struct: `shop`,
  `title`, `price`, `currency`, `discount_pct`, `url`, `fetched_at` (region
  omitted - both current adapters are EUR-only storefronts with no
  region parameter).

**New service** - `services/key_shop_price_service.py`:
- `async def search_key_shops(title: str) -> list[KeyShopOffer]` - runs all
  registered adapters concurrently via
  `asyncio.gather(..., return_exceptions=True)` so one broken/timing-out
  adapter can't block the others, logs failures per-adapter, returns the
  flattened list of successful offers.

**New route** - `GET /api/games/key-shop-prices?title=<title>`, added to
`authenticated_games_router` in `routes/games.py` (JWT-protected, matches
this repo's existing games routes - no unauthenticated internal endpoint was
introduced since, unlike `/api/prices/check`, this isn't machine-to-machine
cron traffic).

No caching/scheduling layer, no new DB table: unlike CheapShark's price
tracking, this endpoint is called on-demand from the entry dialog exactly
like `search_game`/`enriched_search` already are, and two Shopify storefronts
at interactive, human-driven request volume don't need a background sweep.
If a third-party rate limit or added shops make live-per-request calls too
slow/heavy, the upgrade path is a `GamePrice`-style cache table + TTL,
following the pattern already established in `services/price_service.py`.

## Verification

- `task test` — `test_key_shops_shopify.py` (mocked `httpx` responses,
  following `test_cheapshark.py`'s `_MockAsyncClient` pattern): parses a
  representative `/search/suggest.json` payload correctly, computes
  `discount_pct` from `compare_at_price_max` vs `price`, returns `[]` on no
  match. `test_key_shop_price_service.py`: a failing adapter doesn't prevent
  the other's results from returning.
- `task lint` (ruff + eslint).
- Manual: `curl` against both shops' live `/search/suggest.json` confirmed
  the response shape while this was written (see the table above); no
  further manual verification needed since both are stateless GET calls
  with a fixed handful of response fields.
</content>
</invoke>

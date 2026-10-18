import { apiClient, apiErrorMessage } from "./client";
import { isHttpUrl } from "~/lib/safeUrl";

export interface GameSearchResult {
  id: number;
  hltbId: number;
  title: string;
  imageUrl: string | null;
  steamAppId: number | null;
  genres: string[];
  platforms: string[];
  mainStory: number;
  mainStoryWithExtras: number;
  completionist: number;
  description: string | null;
  publisher: string | null;
  trailerUrl: string | null;
}

/**
 * `steamAppId` on each result is always null here - IGDB has no Steam
 * App ID mapping, so it's looked up separately (by title, against
 * Steam's app catalogue) via getSteamAppId once a result is selected,
 * see useSteamAppId. `deep` is the "search more" mode that finds games
 * the normal search misses (bundles, titles spelled with other
 * punctuation).
 */
export async function enrichedSearch(
  searchTerm: string,
  deep = false,
): Promise<GameSearchResult[]> {
  const { data, error } = await apiClient.GET("/api/games/enriched-search", {
    params: { query: { search_term: searchTerm, deep } },
  });
  if (error) throw new Error(apiErrorMessage(error, "Game search failed"));
  return data.map((result) => ({
    id: result.id,
    hltbId: result.hltb_id,
    title: result.title,
    imageUrl: result.image_url,
    steamAppId: null,
    genres: result.genres,
    platforms: result.platforms,
    mainStory: result.main_story,
    mainStoryWithExtras: result.main_story_with_extras,
    completionist: result.completionist,
    description: result.description ?? null,
    publisher: result.publisher ?? null,
    trailerUrl: result.trailer_url ?? null,
  }));
}

export async function getSteamAppId(title: string): Promise<number | null> {
  const { data, error } = await apiClient.GET("/api/games/steam-app-id", {
    params: { query: { title } },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to look up Steam App ID"));
  return data;
}

export async function getSteamGridDbCovers(
  steamAppId: number,
): Promise<string[]> {
  const { data, error } = await apiClient.GET("/api/games/steamgriddb-covers", {
    params: { query: { steam_app_id: steamAppId } },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load cover options"));
  return data;
}

export async function getSteamGridDbCoversById(
  gameId: number,
): Promise<string[]> {
  const { data, error } = await apiClient.GET(
    "/api/games/steamgriddb-covers-by-id",
    { params: { query: { game_id: gameId } } },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load cover options"));
  return data;
}

export interface SteamGridDbSearchResult {
  id: number;
  name: string;
}

export async function searchSteamGridDb(
  searchTerm: string,
): Promise<SteamGridDbSearchResult[]> {
  const { data, error } = await apiClient.GET("/api/games/steamgriddb-search", {
    params: { query: { search_term: searchTerm } },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "SteamGridDB search failed"));
  return data;
}

export interface GamePriceInfo {
  steamAppId: number;
  checkedAt: string;
  currency: string | null;
  currentRetail: number | null;
  currentKeyshops: number | null;
  historicalRetail: number | null;
  historicalKeyshops: number | null;
  url: string | null;
}

function priceOrNull(value: string | null | undefined): number | null {
  return value === null || value === undefined ? null : Number(value);
}

export async function getGamePrice(steamAppId: number): Promise<GamePriceInfo> {
  const { data, error } = await apiClient.GET(
    "/api/games/{steam_app_id}/price",
    {
      params: { path: { steam_app_id: steamAppId } },
    },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load price info"));
  return {
    steamAppId: data.steam_app_id,
    checkedAt: data.checked_at,
    currency: data.currency ?? null,
    currentRetail: priceOrNull(data.current_retail),
    currentKeyshops: priceOrNull(data.current_keyshops),
    historicalRetail: priceOrNull(data.historical_retail),
    historicalKeyshops: priceOrNull(data.historical_keyshops),
    url: data.url && isHttpUrl(data.url) ? data.url : null,
  };
}

export interface KeyShopOffer {
  shop: string;
  title: string;
  price: number;
  currency: string;
  url: string;
  discountPct: number | null;
}

export async function getKeyShopPrices(title: string): Promise<KeyShopOffer[]> {
  const { data, error } = await apiClient.GET("/api/games/key-shop-prices", {
    params: { query: { title } },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load key shop prices"));
  return data
    .filter((offer) => isHttpUrl(offer.url))
    .map((offer) => ({
      shop: offer.shop,
      title: offer.title,
      price: Number(offer.price),
      currency: offer.currency,
      url: offer.url,
      discountPct: offer.discount_pct ?? null,
    }));
}

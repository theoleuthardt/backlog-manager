import { apiClient, apiErrorMessage } from "./client";

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
}

/**
 * `steamAppId` on each result is always null here - IGDB has no Steam
 * App ID mapping, so it's looked up separately (by title, against
 * Steam's app catalogue) via getSteamAppId once a result is selected,
 * see useSteamAppId.
 */
export async function enrichedSearch(
  searchTerm: string,
): Promise<GameSearchResult[]> {
  const { data, error } = await apiClient.GET("/api/games/enriched-search", {
    params: { query: { search_term: searchTerm } },
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

export interface GamePriceDeal {
  store: string;
  iconUrl: string;
  price: number;
  retailPrice: number;
  url: string;
}

export interface GamePriceInfo {
  steamAppId: number;
  deals: GamePriceDeal[];
  onSale: boolean;
  checkedAt: string;
  cheapestPriceEver: number | null;
  cheapestPriceEverDate: string | null;
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
    deals: data.deals.map((deal) => ({
      store: String(deal.store),
      iconUrl: String(deal.icon),
      price: Number(deal.price),
      retailPrice: Number(deal.retail_price),
      url: String(deal.url),
    })),
    onSale: data.on_sale,
    checkedAt: data.checked_at,
    cheapestPriceEver: data.cheapest_price_ever
      ? Number(data.cheapest_price_ever)
      : null,
    cheapestPriceEverDate: data.cheapest_price_ever_date ?? null,
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
  return data.map((offer) => ({
    shop: offer.shop,
    title: offer.title,
    price: Number(offer.price),
    currency: offer.currency,
    url: offer.url,
    discountPct: offer.discount_pct ?? null,
  }));
}

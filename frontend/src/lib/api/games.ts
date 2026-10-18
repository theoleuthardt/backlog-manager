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

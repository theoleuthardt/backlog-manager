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
    // IGDB has no Steam App ID mapping - looked up separately (by
    // title, against Steam's app catalogue) via getSteamAppId once a
    // result is selected, see useSteamAppId.
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
  const { data, error } = await apiClient.GET(
    "/api/games/steamgriddb-covers",
    {
      params: { query: { steam_app_id: steamAppId } },
    },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load cover options"));
  return data;
}

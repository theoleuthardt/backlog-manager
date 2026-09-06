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
    // Always null from the backend - IGDB has no Steam App ID mapping,
    // this field only exists for parity with the old tRPC shape.
    steamAppId: null,
    genres: result.genres,
    platforms: result.platforms,
    mainStory: result.main_story,
    mainStoryWithExtras: result.main_story_with_extras,
    completionist: result.completionist,
  }));
}

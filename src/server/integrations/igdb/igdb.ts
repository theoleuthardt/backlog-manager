import type {
  IGDBSearchResult,
  IGDBTokenResponse,
} from "~/server/integrations/types";

export async function generateIGDBToken(
  clientId: string,
  clientSecret: string,
): Promise<IGDBTokenResponse> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 60000);
  const url: string = `https://id.twitch.tv/oauth2/token?client_id=${clientId}&client_secret=${clientSecret}&grant_type=client_credentials`;
  const options: RequestInit = {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    signal: controller.signal,
  };

  try {
    const response: Response = await fetch(url, options);
    const data: IGDBTokenResponse = await response.json();
    clearTimeout(timeoutId);

    if (!response.ok) {
      console.error(`IGDB API error: ${response.status}`);
      return {};
    }

    return data;
  } catch (err) {
    console.error("Error generating IGDB token:", err);
    throw err;
  }
}

export async function searchGameOnIGDB(
  searchTerm: string,
  clientId: string,
  accessToken: string,
): Promise<IGDBSearchResult[]> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 60000);
  const options: RequestInit = {
    method: "POST",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${accessToken}`,
      "Client-ID": clientId,
    },
    body:
      "fields alternative_name,character,checksum,collection,company,description,game,name,platform,published_at,test_dummy,theme; " +
      `where name = ${searchTerm};`,
    signal: controller.signal,
  };

  try {
    const response: Response = await fetch(
      "https://api.igdb.com/v4/search",
      options,
    );
    const data: IGDBSearchResult[] = await response.json();
    clearTimeout(timeoutId);

    if (!response.ok) {
      console.error(`IGDB API error: ${response.status}`);
      return [];
    }

    return data;
  } catch (err) {
    console.error("Error searching IGDB game:", err);
    throw err;
  }
}

export async function getGameOnIGDB(
  gameId: string,
  clientId: string,
  accessToken: string,
): Promise<[]> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 60000);
  const options: RequestInit = {
    method: "POST",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${accessToken}`,
      "Client-ID": clientId,
    },
    body:
      "fields age_ratings,aggregated_rating,aggregated_rating_count,alternative_names,artworks,bundles,category,checksum," +
      "collection,collections,cover,created_at,dlcs,expanded_games,expansions,external_games,first_release_date,follows," +
      "forks,franchise,franchises,game_engines,game_localizations,game_modes,game_status,game_type,genres,hypes," +
      "involved_companies,keywords,language_supports,multiplayer_modes,name,parent_game,platforms,player_perspectives," +
      "ports,rating,rating_count,release_dates,remakes,remasters,screenshots,similar_games,slug,standalone_expansions," +
      "status,storyline,summary,tags,themes,total_rating,total_rating_count,updated_at,url,version_parent,version_title," +
      "videos,websites;" +
      `where id = ${gameId};`,
    signal: controller.signal,
  };

  try {
    const response: Response = await fetch(
      "https://api.igdb.com/v4/games",
      options,
    );
    const data: [] = await response.json();
    clearTimeout(timeoutId);

    if (!response.ok) {
      console.error(`IGDB API error: ${response.status}`);
      return [];
    }

    return data;
  } catch (err) {
    console.error("Error getting IGDB game:", err);
    throw err;
  }
}

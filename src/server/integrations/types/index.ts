// HowLongToBeat API
export interface HltbResultData {
  id: number;
  hltbId: number;
  title: string;
  imageUrl: string;
  steamAppId: number | null;
  gogAppId: number | null;
  mainStory: number;
  mainStoryWithExtras: number;
  completionist: number;
  lastUpdatedAt: string;
}

// IGDB API
export interface IGDBTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

export interface IGDBSearchResult {
  id: number;
  alternative_name: string;
  game: number;
  name: string;
  publishedAt: number;
}

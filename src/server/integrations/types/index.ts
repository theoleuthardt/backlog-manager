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
  alternative_name?: string;
  game?: number;
  name?: string;
  publishedAt?: number;
}

export interface IGDBGameData {
  id: number;
  age_ratings?: number[];
  aggregated_rating?: number;
  aggregated_rating_count?: number;
  alternative_names?: number[];
  artworks?: number[];
  bundles?: number[];
  cover?: number;
  created_at?: number;
  dlcs?: number[];
  expansions?: number[];
  external_games?: number[];
  first_release_date?: number;
  franchises?: number[];
  game_engines?: number[];
  game_modes?: number[];
  genres?: number[];
  hypes?: number;
  involved_companies?: number[];
  keywords?: number[];
  name?: string;
  platforms?: number[];
  player_perspectives?: number[];
  rating?: number;
  rating_count?: number;
  release_dates?: number[];
  screenshots?: number[];
  similar_games?: number[];
  slug?: string;
  storyline?: string;
  summary?: string;
  tags?: number[];
  themes?: number[];
  total_rating?: number;
  total_rating_count?: number;
  updated_at?: number;
  url?: string;
  videos?: number[];
  websites?: number[];
  checksum?: string;
  language_supports?: number[];
  game_localizations?: number[];
  collections?: number[];
  game_type?: number;
}

export interface IGDBPlatform {
  id: number;
  abbreviation?: string;
  alternative_name?: string;
  category?: number;
  checksum?: string;
  created_at?: number;
  generation?: number;
  name?: string;
  platform_family?: number;
  platform_logo?: number;
  platform_type?: number;
  slug?: string;
  summary?: string;
  updated_at?: number;
  url?: string;
  versions?: number[];
  websites?: number[];
}

export interface IGDBGameTimeToBeat {
  id: number;
  checksum?: string;
  completely?: number;
  count?: number;
  created_at?: number;
  game_id?: number;
  hastily?: number;
  normally?: number;
  updated_at?: number;
}

export interface IGDBCover {
  id: number;
  alpha_channel?: boolean;
  animated?: boolean;
  checksum?: string;
  game?: number;
  game_localization?: number;
  height?: number;
  image_id?: string;
  url?: string;
  width?: number;
}

export interface IGDBGenre {
  id: number;
  checksum?: string;
  created_at?: number;
  name?: string;
  slug?: string;
  updated_at?: number;
  url?: string;
}

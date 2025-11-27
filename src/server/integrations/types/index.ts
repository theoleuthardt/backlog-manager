// HowLongToBeat API
export interface HltbSearchResultItem {
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
export type HltbSearchResult = HltbSearchResultItem[];
export type HltbGame = HltbSearchResultItem;

// IGDB API

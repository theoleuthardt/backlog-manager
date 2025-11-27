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

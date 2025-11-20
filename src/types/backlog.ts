/**
 * Backlog entry properties for display and form
 */
export interface BacklogEntryProps {
  title: string;
  playtime?: number;
  imageLink: string;
  imageAlt?: string;
  genre?: string[];
  platform?: string[];
  status?: string;
  owned?: boolean;
  interest?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  className?: string;
}

/**
 * Backlog entry data structure (includes ID)
 */
export interface BacklogEntryData {
  id: number;
  title: string;
  playtime?: number;
  imageLink: string;
  imageAlt?: string;
  genre?: string[];
  platform?: string[];
  status?: string;
  owned?: boolean;
  interest?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
}

/**
 * Game search result from game database
 */
export interface GameSearchResult {
  title: string;
  imageUrl: string;
  steamAppId: number;
  mainStory: number;
  mainStoryWithExtras: number;
  completionist: number;
}

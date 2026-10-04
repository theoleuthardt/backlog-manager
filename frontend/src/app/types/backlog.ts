/**
 * Backlog entry properties for display and form
 */
export interface BacklogEntryProps {
  id: number;
  title: string;
  playtime?: number;
  partnerPlaytime?: number;
  inSharedSpace?: boolean;
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
  description?: string;
  trailerLink?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  steamAppId?: number;
  completedAt?: string;
  className?: string;
}

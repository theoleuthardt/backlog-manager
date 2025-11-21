export interface UserRow {
  UserID: bigint;
  Username: string;
  Email: string;
  PasswordHash: string;
  CreatedAt: string;
  UpdatedAt: string;
}

export interface CategoryRow {
  CategoryID: bigint;
  UserID: bigint;
  CategoryName: string;
  Color: string;
  Description: string;
  CreatedAt: string;
  UpdatedAt: string;
}

export interface BacklogEntryRow {
  BacklogEntryID: bigint;
  UserID: bigint;
  Title: string;
  Genre: string;
  Platform: string;
  ReleaseDate?: string;
  ImageLink?: string;
  MainTime?: number;
  MainPlusExtraTime?: number;
  CompletionTime?: number;
  Status: string;
  Owned: boolean;
  Interest: bigint;
  ReviewStars?: bigint;
  Review?: string;
  Note?: string;
  CompletedAt?: string;
  CreatedAt: string;
  UpdatedAt: string;
}

export interface BacklogCategoryRow {
  CategoryID: bigint;
  BacklogEntryID: bigint;
  CreatedAt: string;
  UpdatedAt: string;
}
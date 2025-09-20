export interface UserRow {
  name: string;
  email: number;
  passwordHash?: string;
}

export interface CategoryRow {
  userID: bigint;
  name: string;
  description?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface BacklogEntryRow {
  userID: bigint;
  gameID: bigint;
  status: string;
  owned: boolean;
  interest: bigint;
  reviewStars?: bigint;
  review?: string;
  note?: string;
  addedAt?: string;
  completedAt?: string;
  updatedAt?: string;
}

export interface GameRow {
  title: string;
  genre: string;
  platform: string;
  releaseDate?: string;
  imageLink?: string;
  howLongToBeat?: string;
  completedAt?: string;
  updatedAt?: string;
}

export interface BacklogCategoryRow {
  categoryID: bigint;
  backlogEntryID: bigint;
  completedAt?: string;
  updatedAt?: string;
}
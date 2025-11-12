export interface UserRow {
    id: bigint;
  name: string;
  email: string;
  passwordHash?: string;
}

export interface CategoryRow {
  userID: bigint;
  categoryID: bigint;
  name: string;
  color: string;
  description?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface BacklogEntryRow {
  backlogEntryID: bigint;
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
  gameID: bigint;
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
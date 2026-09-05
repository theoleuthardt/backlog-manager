import type {
  UserRow,
  CategoryRow,
  BacklogEntryRow,
  BacklogCategoryRow,
} from "../types";

/**
 * Type mappers to convert database rows (with bigint) to application types (with number)
 * This ensures type consistency across the application
 */

/**
 * User type for application use (with number IDs)
 */
export interface User {
  id: number;
  name: string;
  email: string;
  passwordHash?: string;
  CreatedAt: string;
  UpdatedAt: string;
}

/**
 * Category type for application use (with number IDs)
 */
export interface Category {
  categoryID: number;
  userID: number;
  name: string;
  color: string;
  description?: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Backlog entry type for application use (with number IDs)
 */
export interface BacklogEntry {
  backlogEntryID: number;
  userID: number;
  title: string;
  genre: string;
  platform: string;
  releaseDate?: string;
  imageLink?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  status: string;
  owned: boolean;
  interest: number;
  reviewStars?: number;
  review?: string;
  note?: string;
  CreatedAt: string;
  CompletedAt?: string;
  UpdatedAt: string;
}

/**
 * Backlog-Category association type for application use
 */
export interface BacklogCategoryAssociation {
  categoryID: number;
  backlogEntryID: number;
  completedAt?: string;
  updatedAt?: string;
}

/**
 * Map UserRow to User
 */
export function mapUser(row: UserRow): User {
  return {
    id: Number(row.UserID),
    name: row.Username,
    email: row.Email,
    passwordHash: row.PasswordHash,
    CreatedAt: row.CreatedAt,
    UpdatedAt: row.UpdatedAt,
  };
}

/**
 * Map CategoryRow to Category
 */
export function mapCategory(row: CategoryRow): Category {
  return {
    categoryID: Number(row.CategoryID),
    userID: Number(row.UserID),
    name: row.CategoryName,
    color: row.Color,
    description: row.Description,
    createdAt: row.CreatedAt,
    updatedAt: row.UpdatedAt,
  };
}

/**
 * Map BacklogEntryRow to BacklogEntry
 */
export function mapBacklogEntry(row: BacklogEntryRow): BacklogEntry {
  return {
    backlogEntryID: Number(row.BacklogEntryID),
    userID: Number(row.UserID),
    title: row.Title,
    genre: row.Genre,
    platform: row.Platform,
    releaseDate: row.ReleaseDate ?? undefined,
    imageLink: row.ImageLink ?? undefined,
    mainTime: row.MainTime ? Number(row.MainTime) : undefined,
    mainPlusExtraTime: row.MainPlusExtraTime
      ? Number(row.MainPlusExtraTime)
      : undefined,
    completionTime: row.CompletionTime ? Number(row.CompletionTime) : undefined,
    status: row.Status,
    owned: row.Owned,
    interest: Number(row.Interest),
    reviewStars: row.ReviewStars ? Number(row.ReviewStars) : undefined,
    review: row.Review ?? undefined,
    note: row.Note ?? undefined,
    CreatedAt: row.CreatedAt,
    CompletedAt: row.CompletedAt ?? undefined,
    UpdatedAt: row.UpdatedAt,
  };
}

/**
 * Map BacklogCategoryRow to BacklogCategoryAssociation
 */
export function mapBacklogCategoryAssociation(
  row: BacklogCategoryRow,
): BacklogCategoryAssociation {
  return {
    categoryID: Number(row.CategoryID),
    backlogEntryID: Number(row.BacklogEntryID),
    completedAt: row.CreatedAt,
    updatedAt: row.UpdatedAt,
  };
}

/**
 * Map array of rows
 */
export function mapUsers(rows: UserRow[]): User[] {
  return rows.map(mapUser);
}

export function mapCategories(rows: CategoryRow[]): Category[] {
  return rows.map(mapCategory);
}

export function mapBacklogEntries(rows: BacklogEntryRow[]): BacklogEntry[] {
  return rows.map(mapBacklogEntry);
}

export function mapBacklogCategoryAssociations(
  rows: BacklogCategoryRow[],
): BacklogCategoryAssociation[] {
  return rows.map(mapBacklogCategoryAssociation);
}

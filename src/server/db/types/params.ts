/**
 * Parameter interfaces for database operations
 * These replace long parameter lists for better maintainability
 */

/**
 * Parameters for creating a new user
 */
export interface CreateUserParams {
  username: string;
  email: string;
  passwordHash: string;
}

/**
 * Parameters for updating a user
 */
export interface UpdateUserParams {
  userId: number;
  username?: string;
  email?: string;
  passwordHash?: string;
}

/**
 * Parameters for creating a category
 */
export interface CreateCategoryParams {
  userId: number;
  categoryName: string;
  color?: string;
  description?: string;
}

/**
 * Parameters for updating a category
 */
export interface UpdateCategoryParams {
  categoryId: number;
  categoryName?: string;
  color?: string;
  description?: string;
}

/**
 * Parameters for creating a backlog entry
 */
export interface CreateBacklogEntryParams {
  userId: number;
  title: string;
  genre: string;
  platform: string;
  status: string;
  owned: boolean;
  interest: number;
  releaseDate?: Date;
  imageLink?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
}

/**
 * Parameters for updating a backlog entry
 */
export interface UpdateBacklogEntryParams {
  backlogEntryId: number;
  title?: string;
  genre?: string;
  platform?: string;
  status?: string;
  owned?: boolean;
  interest?: number;
  releaseDate?: Date;
  imageLink?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
}

/**
 * Parameters for category-backlog entry association
 */
export interface CategoryBacklogAssociationParams {
  categoryId: number;
  backlogEntryId: number;
}

/**
 * Parameters for querying backlog entries by status
 */
export interface GetEntriesByStatusParams {
  userId: number;
  status: string;
}

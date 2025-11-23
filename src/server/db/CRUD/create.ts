import type { Pool } from "pg";
import type {
  CreateUserParams,
  CreateCategoryParams,
  CreateBacklogEntryParams,
  CategoryBacklogAssociationParams,
} from "../types/params";
import { handleDatabaseError } from "../types/errors";
import type {
  UserRow,
  CategoryRow,
  BacklogEntryRow,
  BacklogCategoryRow,
} from "../types";
import {
  mapUser,
  mapCategory,
  mapBacklogEntry,
  mapBacklogCategoryAssociation,
  type User,
  type Category,
  type BacklogEntry,
  type BacklogCategoryAssociation,
} from "../utils/mapper";

/**
 * Create a new user
 */
export async function createUser(
  pool: Pool,
  params: CreateUserParams
): Promise<User> {
  const query =
    'INSERT INTO "blm-system"."Users" ("Username", "Email", "PasswordHash", "SteamId") VALUES ($1, $2, $3, $4) RETURNING *';

  try {
    const result = await pool.query(query, [
      params.username,
      params.email,
      params.passwordHash,
      params.steamId,
    ]);
    return mapUser(result.rows[0] as UserRow);
  } catch (error) {
    handleDatabaseError(error, "createUser");
  }
}

/**
 * Create a new category
 */
export async function createCategory(
  pool: Pool,
  params: CreateCategoryParams
): Promise<Category> {
  const query =
    'INSERT INTO "blm-system"."Categories" ("UserID", "CategoryName", "Color", "Description") VALUES ($1, $2, $3, $4) RETURNING *';

  try {
    const result = await pool.query(query, [
      params.userId,
      params.categoryName,
      params.color ?? "#000000",
      params.description ?? "No description",
    ]);
    return mapCategory(result.rows[0] as CategoryRow);
  } catch (error) {
    handleDatabaseError(error, "createCategory");
  }
}

/**
 * Create a new backlog entry
 */
export async function createBacklogEntry(
  pool: Pool,
  params: CreateBacklogEntryParams
): Promise<BacklogEntry> {
  const query =
    'INSERT INTO "blm-system"."BacklogEntries" ("UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest", "ReleaseDate", "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime", "ReviewStars", "Review", "Note") VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15) RETURNING *';

  try {
    const result = await pool.query(query, [
      params.userId,
      params.title,
      params.genre,
      params.platform,
      params.status,
      params.owned,
      params.interest,
      params.releaseDate ?? null,
      params.imageLink ?? null,
      params.mainTime ?? null,
      params.mainPlusExtraTime ?? null,
      params.completionTime ?? null,
      params.reviewStars ?? null,
      params.review ?? null,
      params.note ?? null,
    ]);
    return mapBacklogEntry(result.rows[0] as BacklogEntryRow);
  } catch (error) {
    handleDatabaseError(error, "createBacklogEntry");
  }
}

/**
 * Add a category to a backlog entry
 */
export async function addCategoryToBacklogEntry(
  pool: Pool,
  params: CategoryBacklogAssociationParams
): Promise<BacklogCategoryAssociation> {
  const query =
    'INSERT INTO "blm-system"."CategoryBacklogEntries" ("CategoryID", "BacklogEntryID") VALUES ($1, $2) RETURNING *';

  try {
    const result = await pool.query(query, [
      params.categoryId,
      params.backlogEntryId,
    ]);
    return mapBacklogCategoryAssociation(result.rows[0] as BacklogCategoryRow);
  } catch (error) {
    handleDatabaseError(error, "addCategoryToBacklogEntry");
  }
}

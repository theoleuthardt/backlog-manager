import type { Pool } from "pg";
import type { GetEntriesByStatusParams } from "../types/params";
import { handleDatabaseError, NotFoundError } from "../types/errors";
import type {
  UserRow,
  CategoryRow,
  BacklogEntryRow,
} from "../types";
import {
  mapUser,
  mapUsers,
  mapCategories,
  mapBacklogEntry,
  mapBacklogEntries,
  type User,
  type Category,
  type BacklogEntry,
} from "../utils/mapper";

/**
 * Get all users
 */
export async function getAllUsers(pool: Pool): Promise<User[]> {
  const query = 'SELECT * FROM "blm-system"."Users"';

  try {
    const result = await pool.query(query);
    return mapUsers(result.rows as UserRow[]);
  } catch (error) {
    handleDatabaseError(error, "getAllUsers");
  }
}

/**
 * Get user by ID
 */
export async function getUserById(pool: Pool, userId: number): Promise<User> {
  const query = 'SELECT * FROM "blm-system"."Users" WHERE "UserID" = $1';

  try {
    const result = await pool.query(query, [userId]);
    if (!result.rows[0]) {
      throw new NotFoundError("User", userId);
    }
    return mapUser(result.rows[0] as UserRow);
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "getUserById");
  }
}

/**
 * Get user by username
 */
export async function getUserByUsername(
  pool: Pool,
  username: string,
): Promise<User | null> {
  const query = 'SELECT * FROM "blm-system"."Users" WHERE "Username" = $1';

  try {
    const result = await pool.query(query, [username]);
    return result.rows[0] ? mapUser(result.rows[0] as UserRow) : null;
  } catch (error) {
    handleDatabaseError(error, "getUserByUsername");
  }
}

/**
 * 
 * Get user by email
 */
export async function getUserByEmail(pool: Pool, email: string) {
  const query = 'SELECT * FROM "blm-system"."Users" WHERE "Email" = $1'
  try {
      const result = await pool.query(query, [email])
      return result.rows[0]
  } catch (error) {
      console.error('Error getting user by email:', error)
      throw error
  }
}

/**
 * Get all categories for a user
 */
export async function getCategoriesByUser(
  pool: Pool,
  userId: number,
): Promise<Category[]> {
  const query = 'SELECT * FROM "blm-system"."Categories" WHERE "UserID" = $1';

  try {
    const result = await pool.query(query, [userId]);
    return mapCategories(result.rows as CategoryRow[]);
  } catch (error) {
    handleDatabaseError(error, "getCategoriesByUser");
  }
}

/**
 * Get all backlog entries for a user
 */
export async function getBacklogEntriesByUser(
  pool: Pool,
  userId: number,
): Promise<BacklogEntry[]> {
  const query =
    'SELECT * FROM "blm-system"."BacklogEntries" WHERE "UserID" = $1';

  try {
    const result = await pool.query(query, [userId]);
    return mapBacklogEntries(result.rows as BacklogEntryRow[]);
  } catch (error) {
    handleDatabaseError(error, "getBacklogEntriesByUser");
  }
}

/**
 * Get backlog entry by ID
 */
export async function getBacklogEntryById(
  pool: Pool,
  backlogEntryId: number,
): Promise<BacklogEntry> {
  const query =
    'SELECT * FROM "blm-system"."BacklogEntries" WHERE "BacklogEntryID" = $1';

  try {
    const result = await pool.query(query, [backlogEntryId]);
    if (!result.rows[0]) {
      throw new NotFoundError("BacklogEntry", backlogEntryId);
    }
    return mapBacklogEntry(result.rows[0] as BacklogEntryRow);
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "getBacklogEntryById");
  }
}

/**
 * Get backlog entries by status
 */
export async function getBacklogEntriesByStatus(
  pool: Pool,
  params: GetEntriesByStatusParams,
): Promise<BacklogEntry[]> {
  const query =
    'SELECT * FROM "blm-system"."BacklogEntries" WHERE "UserID" = $1 AND "Status" = $2';

  try {
    const result = await pool.query(query, [params.userId, params.status]);
    return mapBacklogEntries(result.rows as BacklogEntryRow[]);
  } catch (error) {
    handleDatabaseError(error, "getBacklogEntriesByStatus");
  }
}

/**
 * Get all categories for a backlog entry
 */
export async function getCategoriesForBacklogEntry(
  pool: Pool,
  backlogEntryId: number,
): Promise<Category[]> {
  const query = `
    SELECT c.*
    FROM "blm-system"."Categories" c
    JOIN "blm-system"."CategoryBacklogEntries" cbe ON c."CategoryID" = cbe."CategoryID"
    WHERE cbe."BacklogEntryID" = $1
  `;

  try {
    const result = await pool.query(query, [backlogEntryId]);
    return mapCategories(result.rows as CategoryRow[]);
  } catch (error) {
    handleDatabaseError(error, "getCategoriesForBacklogEntry");
  }
}

/**
 * Get all backlog entries for a category
 */
export async function getBacklogEntriesForCategory(
  pool: Pool,
  categoryId: number,
): Promise<BacklogEntry[]> {
  const query = `
    SELECT be.*
    FROM "blm-system"."BacklogEntries" be
    JOIN "blm-system"."CategoryBacklogEntries" cbe ON be."BacklogEntryID" = cbe."BacklogEntryID"
    WHERE cbe."CategoryID" = $1
  `;

  try {
    const result = await pool.query(query, [categoryId]);
    return mapBacklogEntries(result.rows as BacklogEntryRow[]);
  } catch (error) {
    handleDatabaseError(error, "getBacklogEntriesForCategory");
  }
}

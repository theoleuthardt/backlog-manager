import type { Pool } from "pg";
import * as createCRUD from "~/server/db/CRUD/create";
import * as readCRUD from "~/server/db/CRUD/read";
import * as updateCRUD from "~/server/db/CRUD/update";
import * as deleteCRUD from "~/server/db/CRUD/delete";

/**
 * BACKLOG ENTRY SERVICE FUNCTIONS
 * 
 * Handles all backlog entry-related database operations
 */

export async function createBacklogEntry(
  pool: Pool,
  userId: number,
  title: string,
  genre: string,
  platform: string,
  status: string,
  owned: boolean,
  interest: number,
  releaseDate?: Date,
  imageLink?: string,
  mainTime?: number,
  mainPlusExtraTime?: number,
  completionTime?: number,
  reviewStars?: number,
  review?: string,
  note?: string
) {
  return await createCRUD.createBacklogEntry(
    pool,
    userId,
    title,
    genre,
    platform,
    status,
    owned,
    interest,
    releaseDate,
    imageLink,
    mainTime,
    mainPlusExtraTime,
    completionTime,
    reviewStars,
    review,
    note
  );
}

export async function getBacklogEntriesByUser(pool: Pool, userId: number) {
  return await readCRUD.getBacklogEntriesByUser(pool, userId);
}

export async function getBacklogEntryById(pool: Pool, backlogEntryId: number) {
  return await readCRUD.getBacklogEntryById(pool, backlogEntryId);
}

export async function getBacklogEntriesByStatus(
  pool: Pool,
  userId: number,
  status: string
) {
  return await readCRUD.getBacklogEntriesByStatus(pool, userId, status);
}

export async function updateBacklogEntry(
  pool: Pool,
  backlogEntryId: number,
  title: string,
  genre: string,
  platform: string,
  status: string,
  owned: boolean,
  interest: number,
  releaseDate?: Date,
  imageLink?: string,
  mainTime?: number,
  mainPlusExtraTime?: number,
  completionTime?: number,
  reviewStars?: number,
  review?: string,
  note?: string
) {
  return await updateCRUD.updateBacklogEntry(
    pool,
    backlogEntryId,
    title,
    genre,
    platform,
    status,
    owned,
    interest,
    releaseDate,
    imageLink,
    mainTime,
    mainPlusExtraTime,
    completionTime,
    reviewStars,
    review,
    note
  );
}

export async function deleteBacklogEntry(pool: Pool, backlogEntryId: number) {
  const client = await pool.connect();
  try {
    await client.query(
      `DELETE FROM "blm-system"."CategoryBacklogEntries"
       WHERE "BacklogEntryID" = $1`,
      [backlogEntryId]
    );
  } finally {
    client.release();
  }
  return await deleteCRUD.deleteBacklogEntry(pool, backlogEntryId);
}

/**
 * CATEGORY-BACKLOG ENTRY ASSOCIATION FUNCTIONS
 *
 * Handles the relationship between categories and backlog entries
 */

export async function addCategoryToBacklogEntry(
  pool: Pool,
  categoryId: number,
  backlogEntryId: number
) {
  return await createCRUD.addCategoryToBacklogEntry(pool, categoryId, backlogEntryId);
}

export async function getCategoriesForBacklogEntry(
  pool: Pool,
  backlogEntryId: number
) {
  return await readCRUD.getCategoriesForBacklogEntry(pool, backlogEntryId);
}

export async function getBacklogEntriesForCategory(pool: Pool, categoryId: number) {
  return await readCRUD.getBacklogEntriesForCategory(pool, categoryId);
}

export async function removeBacklogEntryFromCategory(
  pool: Pool,
  categoryId: number,
  backlogEntryId: number
) {
  return await deleteCRUD.removeBacklogEntryFromCategory(pool, categoryId, backlogEntryId);
}


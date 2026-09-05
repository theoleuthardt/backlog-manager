import type { Pool } from "pg";
import type {
  CreateBacklogEntryParams,
  UpdateBacklogEntryParams,
  CategoryBacklogAssociationParams,
  GetEntriesByStatusParams,
} from "~/server/db/types/params";
import * as createCRUD from "~/server/db/CRUD/create";
import * as readCRUD from "~/server/db/CRUD/read";
import * as updateCRUD from "~/server/db/CRUD/update";
import * as deleteCRUD from "~/server/db/CRUD/delete";
import type {
  BacklogEntry,
  Category,
  BacklogCategoryAssociation,
} from "~/server/db/utils/mapper";

/**
 * BACKLOG ENTRY SERVICE FUNCTIONS
 *
 * Handles all backlog entry-related business logic
 */

/**
 * Create a new backlog entry
 */
export async function createBacklogEntry(
  pool: Pool,
  params: CreateBacklogEntryParams
): Promise<BacklogEntry> {
  return await createCRUD.createBacklogEntry(pool, params);
}

/**
 * Get all backlog entries for a user
 */
export async function getBacklogEntriesByUser(
  pool: Pool,
  userId: number
): Promise<BacklogEntry[]> {
  return await readCRUD.getBacklogEntriesByUser(pool, userId);
}

/**
 * Get a backlog entry by ID
 */
export async function getBacklogEntryById(
  pool: Pool,
  backlogEntryId: number
): Promise<BacklogEntry> {
  return await readCRUD.getBacklogEntryById(pool, backlogEntryId);
}

/**
 * Get backlog entries by status
 */
export async function getBacklogEntriesByStatus(
  pool: Pool,
  params: GetEntriesByStatusParams
): Promise<BacklogEntry[]> {
  return await readCRUD.getBacklogEntriesByStatus(pool, params);
}

/**
 * Update a backlog entry
 */
export async function updateBacklogEntry(
  pool: Pool,
  params: UpdateBacklogEntryParams
): Promise<BacklogEntry> {
  return await updateCRUD.updateBacklogEntry(pool, params);
}

/**
 * Delete a backlog entry (with cascading deletes in transaction)
 */
export async function deleteBacklogEntry(
  pool: Pool,
  backlogEntryId: number
): Promise<BacklogEntry> {
  return await deleteCRUD.deleteBacklogEntry(pool, backlogEntryId);
}

/**
 * CATEGORY-BACKLOG ENTRY ASSOCIATION FUNCTIONS
 *
 * Handles the relationship between categories and backlog entries
 */

/**
 * Add a category to a backlog entry
 */
export async function addCategoryToBacklogEntry(
  pool: Pool,
  params: CategoryBacklogAssociationParams
): Promise<BacklogCategoryAssociation> {
  return await createCRUD.addCategoryToBacklogEntry(pool, params);
}

/**
 * Get all categories for a backlog entry
 */
export async function getCategoriesForBacklogEntry(
  pool: Pool,
  backlogEntryId: number
): Promise<Category[]> {
  return await readCRUD.getCategoriesForBacklogEntry(pool, backlogEntryId);
}

/**
 * Get all backlog entries for a category
 */
export async function getBacklogEntriesForCategory(
  pool: Pool,
  categoryId: number
): Promise<BacklogEntry[]> {
  return await readCRUD.getBacklogEntriesForCategory(pool, categoryId);
}

/**
 * Remove a backlog entry from a category
 */
export async function removeBacklogEntryFromCategory(
  pool: Pool,
  params: CategoryBacklogAssociationParams
): Promise<BacklogCategoryAssociation> {
  return await deleteCRUD.removeBacklogEntryFromCategory(pool, params);
}

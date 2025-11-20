import type { Pool } from "pg";
import * as createCRUD from "~/server/db/CRUD/create";
import * as readCRUD from "~/server/db/CRUD/read";
import * as updateCRUD from "~/server/db/CRUD/update";
import * as deleteCRUD from "~/server/db/CRUD/delete";

/**
 * CATEGORY SERVICE FUNCTIONS
 *
 * Handles all category-related database operations
 */

export async function createCategory(
  pool: Pool,
  userId: number,
  categoryName: string,
  color: string = "#000000",
  description: string = "No description"
) {
  return await createCRUD.createCategory(pool, userId, categoryName, color, description);
}

export async function getCategoriesByUser(pool: Pool, userId: number) {
  return await readCRUD.getCategoriesByUser(pool, userId);
}

export async function updateCategory(
  pool: Pool,
  categoryId: number,
  categoryName: string,
  color: string,
  description: string
) {
  return await updateCRUD.updateCategory(pool, categoryId, categoryName, color, description);
}

export async function deleteCategory(pool: Pool, categoryId: number) {
  // First delete all category-backlog entry associations
  await deleteCRUD.deleteCategoryBacklogEntries(pool, categoryId);
  // Then delete the category
  return await deleteCRUD.deleteCategory(pool, categoryId);
}


import type { Pool } from "pg";
import type {
  CreateCategoryParams,
  UpdateCategoryParams,
} from "~/server/db/types/params";
import * as createCRUD from "~/server/db/CRUD/create";
import * as readCRUD from "~/server/db/CRUD/read";
import * as updateCRUD from "~/server/db/CRUD/update";
import * as deleteCRUD from "~/server/db/CRUD/delete";
import type { Category } from "~/server/db/utils/mapper";

/**
 * CATEGORY SERVICE FUNCTIONS
 *
 * Handles all category-related business logic
 */

/**
 * Create a new category
 */
export async function createCategory(
  pool: Pool,
  params: CreateCategoryParams
): Promise<Category> {
  return await createCRUD.createCategory(pool, params);
}

/**
 * Get all categories for a user
 */
export async function getCategoriesByUser(
  pool: Pool,
  userId: number
): Promise<Category[]> {
  return await readCRUD.getCategoriesByUser(pool, userId);
}

/**
 * Update a category
 */
export async function updateCategory(
  pool: Pool,
  params: UpdateCategoryParams
): Promise<Category> {
  return await updateCRUD.updateCategory(pool, params);
}

/**
 * Delete a category (with cascading deletes in transaction)
 */
export async function deleteCategory(
  pool: Pool,
  categoryId: number
): Promise<Category> {
  return await deleteCRUD.deleteCategory(pool, categoryId);
}

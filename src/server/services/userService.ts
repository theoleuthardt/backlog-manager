import type { Pool } from "pg";
import * as createCRUD from "~/server/db/CRUD/create";
import * as readCRUD from "~/server/db/CRUD/read";
import * as updateCRUD from "~/server/db/CRUD/update";
import * as deleteCRUD from "~/server/db/CRUD/delete";

/**
 * USER SERVICE FUNCTIONS
 *
 * Handles all user-related database operations
 */

/**
 * CREATE OPERATIONS
 */
export async function createUser(
  pool: Pool,
  username: string,
  email: string,
  passwordHash: string
) {
  return await createCRUD.createUser(pool, username, email, passwordHash);
}

/**
 * READ OPERATIONS
 */
export async function getAllUsers(pool: Pool) {
  return await readCRUD.getAllUsers(pool);
}

export async function getUserById(pool: Pool, userId: number) {
  return await readCRUD.getUserById(pool, userId);
}

export async function getUserByUsername(pool: Pool, username: string) {
  return await readCRUD.getUserByUsername(pool, username);
}

/**
 * UPDATE OPERATIONS
 */
export async function updateUser(
  pool: Pool,
  userId: number,
  username: string,
  email: string,
  passwordHash: string
) {
  return await updateCRUD.updateUser(pool, userId, username, email, passwordHash);
}

/**
 * DELETE OPERATIONS
 */
export async function deleteUser(pool: Pool, userId: number) {
  return await deleteCRUD.deleteUser(pool, userId);
}


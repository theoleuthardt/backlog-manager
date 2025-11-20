import type { Pool } from "pg";
import type {
  CreateUserParams,
  UpdateUserParams,
} from "~/server/db/types/params";
import * as createCRUD from "~/server/db/CRUD/create";
import * as readCRUD from "~/server/db/CRUD/read";
import * as updateCRUD from "~/server/db/CRUD/update";
import * as deleteCRUD from "~/server/db/CRUD/delete";
import type { User } from "~/server/db/utils/mapper";

/**
 * USER SERVICE FUNCTIONS
 *
 * Handles all user-related business logic
 */

/**
 * Create a new user
 */
export async function createUser(
  pool: Pool,
  params: CreateUserParams
): Promise<User> {
  return await createCRUD.createUser(pool, params);
}

/**
 * Get all users
 */
export async function getAllUsers(pool: Pool): Promise<User[]> {
  return await readCRUD.getAllUsers(pool);
}

/**
 * Get a user by ID
 */
export async function getUserById(pool: Pool, userId: number): Promise<User> {
  return await readCRUD.getUserById(pool, userId);
}

/**
 * Get a user by username
 */
export async function getUserByUsername(
  pool: Pool,
  username: string
): Promise<User | null> {
  return await readCRUD.getUserByUsername(pool, username);
}

/**
 * Update a user
 */
export async function updateUser(
  pool: Pool,
  params: UpdateUserParams
): Promise<User> {
  return await updateCRUD.updateUser(pool, params);
}

/**
 * Delete a user (with cascading deletes in transaction)
 */
export async function deleteUser(pool: Pool, userId: number): Promise<User> {
  return await deleteCRUD.deleteUser(pool, userId);
}

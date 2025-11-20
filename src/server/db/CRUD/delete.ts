import type { Pool } from "pg";
import type { CategoryBacklogAssociationParams } from "../types/params";
import { handleDatabaseError, NotFoundError } from "../types/errors";
import { withTransaction } from "../utils/transaction";
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
 * Delete a user (and all related data in a transaction)
 */
export async function deleteUser(pool: Pool, userId: number): Promise<User> {
  try {
    return await withTransaction(pool, async (client) => {
      const userResult = await client.query(
        'SELECT * FROM "blm-system"."Users" WHERE "UserID" = $1',
        [userId],
      );

      if (!userResult.rows[0]) {
        throw new NotFoundError("User", userId);
      }

      await client.query(
        `DELETE FROM "blm-system"."CategoryBacklogEntries"
         WHERE "BacklogEntryID" IN (
           SELECT "BacklogEntryID" FROM "blm-system"."BacklogEntries" WHERE "UserID" = $1
         )`,
        [userId],
      );

      await client.query(
        'DELETE FROM "blm-system"."BacklogEntries" WHERE "UserID" = $1',
        [userId],
      );

      await client.query(
        'DELETE FROM "blm-system"."Categories" WHERE "UserID" = $1',
        [userId],
      );

      await client.query(
        'DELETE FROM "blm-system"."Users" WHERE "UserID" = $1',
        [userId],
      );

      return mapUser(userResult.rows[0]);
    });
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "deleteUser");
  }
}

/**
 * Delete a category (and all related associations in a transaction)
 */
export async function deleteCategory(
  pool: Pool,
  categoryId: number,
): Promise<Category> {
  try {
    return await withTransaction(pool, async (client) => {
      const categoryResult = await client.query(
        'SELECT * FROM "blm-system"."Categories" WHERE "CategoryID" = $1',
        [categoryId],
      );

      if (!categoryResult.rows[0]) {
        throw new NotFoundError("Category", categoryId);
      }

      await client.query(
        'DELETE FROM "blm-system"."CategoryBacklogEntries" WHERE "CategoryID" = $1',
        [categoryId],
      );

      await client.query(
        'DELETE FROM "blm-system"."Categories" WHERE "CategoryID" = $1',
        [categoryId],
      );

      return mapCategory(categoryResult.rows[0]);
    });
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "deleteCategory");
  }
}

/**
 * Delete a backlog entry (and all related associations in a transaction)
 */
export async function deleteBacklogEntry(
  pool: Pool,
  backlogEntryId: number,
): Promise<BacklogEntry> {
  try {
    return await withTransaction(pool, async (client) => {
      const entryResult = await client.query(
        'SELECT * FROM "blm-system"."BacklogEntries" WHERE "BacklogEntryID" = $1',
        [backlogEntryId],
      );

      if (!entryResult.rows[0]) {
        throw new NotFoundError("BacklogEntry", backlogEntryId);
      }

      await client.query(
        'DELETE FROM "blm-system"."CategoryBacklogEntries" WHERE "BacklogEntryID" = $1',
        [backlogEntryId],
      );

      await client.query(
        'DELETE FROM "blm-system"."BacklogEntries" WHERE "BacklogEntryID" = $1',
        [backlogEntryId],
      );

      return mapBacklogEntry(entryResult.rows[0]);
    });
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "deleteBacklogEntry");
  }
}

/**
 * Remove a backlog entry from a category (delete association)
 */
export async function removeBacklogEntryFromCategory(
  pool: Pool,
  params: CategoryBacklogAssociationParams,
): Promise<BacklogCategoryAssociation> {
  const client = await pool.connect();
  try {
    const result = await client.query(
      'DELETE FROM "blm-system"."CategoryBacklogEntries" WHERE "CategoryID" = $1 AND "BacklogEntryID" = $2 RETURNING *',
      [params.categoryId, params.backlogEntryId],
    );

    if (!result.rows[0]) {
      throw new NotFoundError(
        "CategoryBacklogAssociation",
        `${params.categoryId}-${params.backlogEntryId}`,
      );
    }

    return mapBacklogCategoryAssociation(result.rows[0]);
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "removeBacklogEntryFromCategory");
  } finally {
    client.release();
  }
}

/**
 * Delete all backlog entries from a category
 */
export async function deleteCategoryBacklogEntries(
  pool: Pool,
  categoryId: number,
): Promise<BacklogCategoryAssociation[]> {
  const client = await pool.connect();
  try {
    const result = await client.query(
      'DELETE FROM "blm-system"."CategoryBacklogEntries" WHERE "CategoryID" = $1 RETURNING *',
      [categoryId],
    );

    return result.rows.map(mapBacklogCategoryAssociation);
  } catch (error) {
    handleDatabaseError(error, "deleteCategoryBacklogEntries");
  } finally {
    client.release();
  }
}

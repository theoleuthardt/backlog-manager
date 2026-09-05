import type { Pool } from "pg";
import type {
  UpdateUserParams,
  UpdateCategoryParams,
  UpdateBacklogEntryParams,
} from "../types/params";
import { handleDatabaseError, NotFoundError } from "../types/errors";
import type { UserRow, CategoryRow, BacklogEntryRow } from "../types";
import {
  mapUser,
  mapCategory,
  mapBacklogEntry,
  type User,
  type Category,
  type BacklogEntry,
} from "../utils/mapper";

/**
 * Update a user
 */
export async function updateUser(
  pool: Pool,
  params: UpdateUserParams,
): Promise<User> {
  const client = await pool.connect();
  try {
    const updates: string[] = [];
    const values: (string | number | null)[] = [params.userId];
    let paramCount = 2;

    if (params.username !== undefined) {
      updates.push(`"Username" = $${paramCount++}`);
      values.push(params.username);
    }
    if (params.email !== undefined) {
      updates.push(`"Email" = $${paramCount++}`);
      values.push(params.email);
    }
    if (params.passwordHash !== undefined) {
      updates.push(`"PasswordHash" = $${paramCount++}`);
      values.push(params.passwordHash);
    }
    if (params.steamId !== undefined) {
      updates.push(`"SteamId" = $${paramCount++}`);
      values.push(params.steamId);
    }

    updates.push(`"UpdatedAt" = DATE_TRUNC('minute', CURRENT_TIMESTAMP)`);

    if (updates.length === 0) {
      const result = await client.query(
        'SELECT * FROM "blm-system"."Users" WHERE "UserID" = $1',
        [params.userId],
      );
      if (!result.rows[0]) {
        throw new NotFoundError("User", params.userId);
      }
      return mapUser(result.rows[0] as UserRow);
    }

    const query = `
      UPDATE "blm-system"."Users"
      SET ${updates.join(", ")}
      WHERE "UserID" = $1
      RETURNING *
    `;

    const result = await client.query(query, values);
    if (!result.rows[0]) {
      throw new NotFoundError("User", params.userId);
    }
    return mapUser(result.rows[0] as UserRow);
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "updateUser");
  } finally {
    client.release();
  }
}


/**
 * Update a category
 */
export async function updateCategory(
  pool: Pool,
  params: UpdateCategoryParams,
): Promise<Category> {
  const client = await pool.connect();
  try {
    const updates: string[] = [];
    const values: (string | number)[] = [params.categoryId];
    let paramCount = 2;

    if (params.categoryName !== undefined) {
      updates.push(`"CategoryName" = $${paramCount++}`);
      values.push(params.categoryName);
    }
    if (params.color !== undefined) {
      updates.push(`"Color" = $${paramCount++}`);
      values.push(params.color);
    }
    if (params.description !== undefined) {
      updates.push(`"Description" = $${paramCount++}`);
      values.push(params.description);
    }

    updates.push(`"UpdatedAt" = DATE_TRUNC('minute', CURRENT_TIMESTAMP)`);

    if (updates.length === 0) {
      const result = await client.query(
        'SELECT * FROM "blm-system"."Categories" WHERE "CategoryID" = $1',
        [params.categoryId],
      );
      if (!result.rows[0]) {
        throw new NotFoundError("Category", params.categoryId);
      }
      return mapCategory(result.rows[0] as CategoryRow);
    }

    const query = `
      UPDATE "blm-system"."Categories"
      SET ${updates.join(", ")}
      WHERE "CategoryID" = $1
      RETURNING *
    `;

    const result = await client.query(query, values);
    if (!result.rows[0]) {
      throw new NotFoundError("Category", params.categoryId);
    }
    return mapCategory(result.rows[0] as CategoryRow);
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "updateCategory");
  } finally {
    client.release();
  }
}

/**
 * Update a backlog entry
 */
export async function updateBacklogEntry(
  pool: Pool,
  params: UpdateBacklogEntryParams,
): Promise<BacklogEntry> {
  const client = await pool.connect();
  try {
    const updates: string[] = [];
    const values: (string | number | boolean | string[] | Date | null)[] = [
      params.backlogEntryId,
    ];
    let paramCount = 2;

    if (params.title !== undefined) {
      updates.push(`"Title" = $${paramCount++}`);
      values.push(params.title);
    }
    if (params.genre !== undefined) {
      updates.push(`"Genre" = $${paramCount++}`);
      values.push(params.genre);
    }
    if (params.platform !== undefined) {
      updates.push(`"Platform" = $${paramCount++}`);
      values.push(params.platform);
    }
    if (params.status !== undefined) {
      updates.push(`"Status" = $${paramCount++}`);
      values.push(params.status);
    }
    if (params.owned !== undefined) {
      updates.push(`"Owned" = $${paramCount++}`);
      values.push(params.owned);
    }
    if (params.interest !== undefined) {
      updates.push(`"Interest" = $${paramCount++}`);
      values.push(params.interest);
    }
    if (params.releaseDate !== undefined) {
      updates.push(`"ReleaseDate" = $${paramCount++}`);
      values.push(params.releaseDate);
    }
    if (params.imageLink !== undefined) {
      updates.push(`"ImageLink" = $${paramCount++}`);
      values.push(params.imageLink);
    }
    if (params.mainTime !== undefined) {
      updates.push(`"MainTime" = $${paramCount++}`);
      values.push(params.mainTime);
    }
    if (params.mainPlusExtraTime !== undefined) {
      updates.push(`"MainPlusExtraTime" = $${paramCount++}`);
      values.push(params.mainPlusExtraTime);
    }
    if (params.completionTime !== undefined) {
      updates.push(`"CompletionTime" = $${paramCount++}`);
      values.push(params.completionTime);
    }
    if (params.reviewStars !== undefined) {
      updates.push(`"ReviewStars" = $${paramCount++}`);
      values.push(params.reviewStars);
    }
    if (params.review !== undefined) {
      updates.push(`"Review" = $${paramCount++}`);
      values.push(params.review);
    }
    if (params.note !== undefined) {
      updates.push(`"Note" = $${paramCount++}`);
      values.push(params.note);
    }

    updates.push(`"UpdatedAt" = DATE_TRUNC('minute', CURRENT_TIMESTAMP)`);

    if (updates.length === 0) {
      const result = await client.query(
        'SELECT * FROM "blm-system"."BacklogEntries" WHERE "BacklogEntryID" = $1',
        [params.backlogEntryId],
      );
      if (!result.rows[0]) {
        throw new NotFoundError("BacklogEntry", params.backlogEntryId);
      }
      return mapBacklogEntry(result.rows[0] as BacklogEntryRow);
    }

    const query = `
      UPDATE "blm-system"."BacklogEntries"
      SET ${updates.join(", ")}
      WHERE "BacklogEntryID" = $1
      RETURNING *
    `;

    const result = await client.query(query, values);
    if (!result.rows[0]) {
      throw new NotFoundError("BacklogEntry", params.backlogEntryId);
    }
    return mapBacklogEntry(result.rows[0] as BacklogEntryRow);
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    handleDatabaseError(error, "updateBacklogEntry");
  } finally {
    client.release();
  }
}

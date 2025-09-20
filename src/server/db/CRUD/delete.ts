import pool from "~/server/db";
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

export const deleteUser = async (userID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "DELETE FROM Users WHERE id = $1 RETURNING *",
      [userID],
    );
    return result.rows[0] as UserRow;
  } catch (error) {
    console.error("Error deleting user:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const deleteCategory = async (categoryID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "DELETE FROM Categories WHERE id = $1 RETURNING *",
      [categoryID],
    );
    return result.rows[0] as CategoryRow;
  } catch (error) {
    console.error("Error deleting category:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const deleteBacklogEntry = async (backlogEntryID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "DELETE FROM BacklogEntries WHERE id = $1 RETURNING *",
      [backlogEntryID],
    );
    return result.rows[0] as BacklogEntryRow;
  } catch (error) {
    console.error("Error deleting backlog entry:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const deleteGame = async (gameID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "DELETE FROM Games WHERE id = $1 RETURNING *",
      [gameID],
    );
    return result.rows[0] as GameRow;
  } catch (error) {
    console.error("Error deleting game:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const removeBacklogEntryFromCategory = async (categoryID: bigint, backlogEntryID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "DELETE FROM CategoryBacklogEntries WHERE categoryID = $1 AND backlogEntryID = $2 RETURNING *",
      [categoryID, backlogEntryID],
    );
    return result.rows[0] as BacklogCategoryRow;
  } catch (error) {
    console.error("Error removing backlog entry from category:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const deleteCategoryBacklogEntries  = async (categoryID: bigint) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "DELETE FROM CategoryBacklogEntries WHERE categoryID = $1 RETURNING *",
            [categoryID],
        );
        return result.rows[0] as BacklogCategoryRow;
    } catch (error) {
        console.error("Error removing backlog entry from category:", error);
        throw error;
    } finally {
        client.release();
    }
};


import pool from "~/server/db";
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

export const getAllUsers = async () => {
  const client = await pool.connect();
  try {
    const result = await client.query("SELECT * FROM Users");
    return result.rows as UserRow[];
  } catch (error) {
    console.error("Error fetching users:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const getUserByID = async (userID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "SELECT * FROM Users WHERE id = $1",
      [userID],
    );
    return result.rows[0] as UserRow;
  } catch (error) {
    console.error("Error fetching user:", error);
    throw error;
  } finally {
    client.release();
  }
};


export const getAllCategories = async () => {
  const client = await pool.connect();
  try {
    const result = await client.query("SELECT * FROM Categories");
    return result.rows as CategoryRow[];
  } catch (error) {
    console.error("Error fetching categories:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const getCategoryByID = async (categoryID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "SELECT * FROM Categories WHERE id = $1",
      [categoryID],
    );
    return result.rows[0] as CategoryRow;
  } catch (error) {
    console.error("Error fetching category:", error);
    throw error;
  } finally {
    client.release();
  }
};


export const getAllBacklogEntries = async () => {
  const client = await pool.connect();
  try {
    const result = await client.query("SELECT * FROM BacklogEntries");
    return result.rows as BacklogEntryRow[];
  } catch (error) {
    console.error("Error fetching backlog entries:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const getBacklogEntryByID = async (backlogEntryID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "SELECT * FROM BacklogEntries WHERE id = $1",
      [backlogEntryID],
    );
    return result.rows[0] as BacklogEntryRow;
  } catch (error) {
    console.error("Error fetching backlog entry:", error);
    throw error;
  } finally {
    client.release();
  }
};


export const getAllGames = async () => {
  const client = await pool.connect();
  try {
    const result = await client.query("SELECT * FROM Games");
    return result.rows as GameRow[];
  } catch (error) {
    console.error("Error fetching games:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const getGameByID = async (gameID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "SELECT * FROM Games WHERE id = $1",
      [gameID],
    );
    return result.rows[0] as GameRow;
  } catch (error) {
    console.error("Error fetching game:", error);
    throw error;
  } finally {
    client.release();
  }
};


export const getBacklogEntriesForCategory = async (categoryID: bigint) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      `SELECT be.* 
       FROM CategoryBacklogEntries cbe
       JOIN BacklogEntries be ON cbe.backlogEntryID = be.id
       WHERE cbe.categoryID = $1`,
      [categoryID],
    );
    return result.rows as BacklogEntryRow[];
  } catch (error) {
    console.error("Error fetching backlog entries for category:", error);
    throw error;
  } finally {
    client.release();
  }
};


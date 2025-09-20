import pool from "~/server/db";
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

export const updateUser = async (userID: bigint, name: string, email: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "UPDATE Users SET name = $2, email = $3 WHERE id = $1 RETURNING *",
      [userID, name, email],
    );
    return result.rows[0] as UserRow;
  } catch (error) {
    console.error("Error updating user:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const updateCategory = async (
  categoryID: bigint,
  name: string,
  color: string,
  description: string,
  createdAt: string,
  updatedAt: string
) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "UPDATE Categories SET name = $2, color = $3, description = $4, createdAt = $5, updatedAt = $6 WHERE id = $1 RETURNING *",
      [categoryID, name, color, description, createdAt, updatedAt],
    );
    return result.rows[0] as CategoryRow;
  } catch (error) {
    console.error("Error updating category:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const updateBacklogEntry = async (
  backlogEntryID: bigint,
  status: string,
  owned: boolean,
  interest: bigint,
  reviewStars: bigint,
  review: string,
  note: string,
  addedAt: string,
  completedAt: string,
  updatedAt: string
) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      `UPDATE BacklogEntries 
       SET status = $2, owned = $3, interest = $4, reviewStars = $5, review = $6, note = $7, addedAt = $8, completedAt = $9, updatedAt = $10 
       WHERE id = $1 RETURNING *`,
      [backlogEntryID, status, owned, interest, reviewStars, review, note, addedAt, completedAt, updatedAt],
    );
    return result.rows[0] as BacklogEntryRow;
  } catch (error) {
    console.error("Error updating backlog entry:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const updateGame = async (
  gameID: bigint,
  title: string,
  genre: string,
  platform: string,
  releaseDate: string,
  imageLink: string,
  howLongToBeat: string,
  addedAt: string,
  updatedAt: string
) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      `UPDATE Games 
       SET title = $2, genre = $3, platform = $4, releaseDate = $5, imageLink = $6, howLongToBeat = $7, addedAt = $8, updatedAt = $9
       WHERE id = $1 RETURNING *`,
      [gameID, title, genre, platform, releaseDate, imageLink, howLongToBeat, addedAt, updatedAt],
    );
    return result.rows[0] as GameRow;
  } catch (error) {
    console.error("Error updating game:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const updateCategoryBacklogEntry = async (
  categoryID: bigint,
  backlogEntryID: bigint,
  newCategoryID: bigint,
  newBacklogEntryID: bigint,
  addedAt: string,
  updatedAt: string
) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      `UPDATE CategoryBacklogEntries 
       SET categoryID = $3, backlogEntryID = $4, addedAt = $5, updatedAt = $6
       WHERE categoryID = $1 AND backlogEntryID = $2
       RETURNING *`,
      [categoryID, backlogEntryID, newCategoryID, newBacklogEntryID, addedAt, updatedAt],
    );
    return result.rows[0] as BacklogCategoryRow;
  } catch (error) {
    console.error("Error updating category-backlog entry relation:", error);
    throw error;
  } finally {
    client.release();
  }
};

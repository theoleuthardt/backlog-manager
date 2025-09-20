import pool from "~/server/db";
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

export const createUser = async (name: string, email: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "INSERT INTO Users (name, email) VALUES ($1, $2) RETURNING *",
      [name, email],
    );
    return result.rows[0] as UserRow;
  } catch (error) {
    console.error("Error creating user:", error);
    throw error;
  } finally {
    client.release();
  }
};

export const createCategory = async (userID: bigint, name: string, color: string, description: string, createdAt: string, updatedAt: string) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO Categories (userID, name, color, description, createdAt, updatedAt) VALUES ($1, $2, $3, $4, $5, $6 RETURNING *",
            [userID, name, color, description, createdAt, updatedAt],
        );
        return result.rows[0] as CategoryRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};

export const createBacklogEntry = async (userID: bigint, gameID: bigint, status: string, owned: boolean, interest: bigint, reviewStars: bigint, review: string, note: string, addedAt: string, completedAt: string, updatedAt: string) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO BacklogEntries (userID, gameID, status, owned, interest, reviewStars, review, note, addedAt, completedAt, updatedAt) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *",
            [userID, gameID, status, owned, interest, reviewStars, review, note, addedAt, completedAt, updatedAt],
        );
        return result.rows[0] as BacklogEntryRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};

export const createGame = async (title: string, genre: string, platform: string, releaseDate: string, imageLink: string, howLongToBeat: string, createdAt: string, updatedAt: string) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO Games (title, genre, platform, releaseDate, imageLink, howLongToBeat, createdAt, updatedAt) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *",
            [title, genre, platform, releaseDate, imageLink, howLongToBeat, createdAt, updatedAt],
        );
        return result.rows[0] as GameRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};

export const addBacklogEntryToCategory = async (categoryID: bigint, backlogEntryID: bigint, createdAt: string, updatedAt: string) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO CategoryBacklogEntries (categoryID, backlogEntryID, createdAt, updatedAt) VALUES ($1, $2, $3, $4) RETURNING *",
            [categoryID, backlogEntryID, createdAt, updatedAt],
        );
        return result.rows[0] as BacklogCategoryRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};
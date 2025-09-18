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

export const createCategory = async (userID: bigint, name: string, color: string, description: string, createdAt: string) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO Categories (userID, name, color, description, createdAt) VALUES ($1, $2, $3, $4, $5) RETURNING *",
            [userID, name, color, description, createdAt],
        );
        return result.rows[0] as CategoryRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};

export const createBacklogEntry = async (userID: bigint, gameID: bigint, status: string, owned: boolean, interest: bigint, reviewNote: string, addedAt: string, completedAt: string) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO BacklogEntries (userID, gameID, status, owned, interest, reviewNote, addedAt, completedAt) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *",
            [userID, gameID, status, owned, interest, reviewNote, addedAt, completedAt],
        );
        return result.rows[0] as BacklogEntryRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};

export const createGame = async (title: string, genre: string, platform: string, releaseDate: string, imageLink: string, howLongToBeat: string) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO Games (title, genre, platform, releaseDate, imageLink, howLongToBeat) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *",
            [title, genre, platform, releaseDate, imageLink, howLongToBeat],
        );
        return result.rows[0] as GameRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};

export const addBacklogEntryToCategory = async (categoryID: bigint, backlogEntryID: bigint) => {
    const client = await pool.connect();
    try {
        const result = await client.query(
            "INSERT INTO CategoryBacklogEntries (categoryID, backlogEntryID) VALUES ($1, $2) RETURNING *",
            [categoryID, backlogEntryID],
        );
        return result.rows[0] as BacklogCategoryRow;
    } catch (error) {
        console.error("Error creating user:", error);
        throw error;
    } finally {
        client.release();
    }
};
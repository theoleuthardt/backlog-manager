import { Pool } from 'pg'
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

// Update User - Only update username, email, and password
export const updateUserByEmail = async (
    pool: Pool,
    email: string,
    username: string,
    passwordHash: string,
    steamId: string | null
  ) => {
    const client = await pool.connect();
    try {
      const result = await client.query(
        `UPDATE "blm-system"."Users"
         SET "Username" = $2,
             "PasswordHash" = $3,
             "SteamId" = $4,
         WHERE "Email" = $1
         RETURNING *`,
        [email, username, passwordHash, steamId]
      );
      return result.rows[0] as UserRow;
    } catch (error) {
      console.error('Error updating user:', error);
      throw error;
    } finally {
      client.release();
    }
  };
  

// Update Category - Don't pass CreatedAt, let DB handle UpdatedAt
export const updateCategory = async (
    pool: Pool,
    categoryID: number,
    categoryName: string,
    color: string,
    description: string
) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `UPDATE "blm-system"."Categories"
             SET "CategoryName" = $2, "Color" = $3, "Description" = $4, "UpdatedAt" = DATE_TRUNC('minute', CURRENT_TIMESTAMP)
             WHERE "CategoryID" = $1
             RETURNING *`,
            [categoryID, categoryName, color, description]
        )
        return result.rows[0] as CategoryRow
    } catch (error) {
        console.error('Error updating category:', error)
        throw error
    } finally {
        client.release()
    }
}

// Update Backlog Entry - Don't update CreatedAt, let DB handle CompletedAt and UpdatedAt
export const updateBacklogEntry = async (
    pool: Pool,
    backlogEntryID: number,
    status: string,
    owned: boolean,
    interest: number,
    reviewStars?: number,
    review?: string,
    note?: string
) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `UPDATE "blm-system"."BacklogEntries" 
       SET "Status" = $2, "Owned" = $3, "Interest" = $4, "ReviewStars" = $5, "Review" = $6, "Note" = $7, "UpdatedAt" = DATE_TRUNC('minute', CURRENT_TIMESTAMP) 
       WHERE "BacklogEntryID" = $1 
       RETURNING *`,
            [backlogEntryID, status, owned, interest, reviewStars || null, review || null, note || null]
        )
        return result.rows[0] as BacklogEntryRow
    } catch (error) {
        console.error('Error updating backlog entry:', error)
        throw error
    } finally {
        client.release()
    }
}

// Update Game - Don't update CreatedAt, let DB handle UpdatedAt
export const updateGame = async (
    pool: Pool,
    gameID: number,
    title: string,
    genre: string,
    platform: string,
    releaseDate?: Date,
    imageLink?: string,
    howLongToBeat?: number[]
) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `UPDATE "blm-system"."Games" 
       SET "Title" = $2, "Genre" = $3, "Platform" = $4, "ReleaseDate" = $5, "ImageLink" = $6, "HowLongToBeat" = $7, "UpdatedAt" = DATE_TRUNC('minute', CURRENT_TIMESTAMP) 
       WHERE "GameID" = $1 
       RETURNING *`,
            [gameID, title, genre, platform, releaseDate || null, imageLink || null, howLongToBeat || null]
        )
        return result.rows[0] as GameRow
    } catch (error) {
        console.error('Error updating game:', error)
        throw error
    } finally {
        client.release()
    }
}

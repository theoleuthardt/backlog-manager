import { Pool } from 'pg'
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";


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
             "SteamId" = $4
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

export const updateBacklogEntry = async (
    pool: Pool,
    backlogEntryID: number,
    title: string,
    genre: string,
    platform: string,
    status: string,
    owned: boolean,
    interest: number,
    releaseDate?: Date,
    imageLink?: string,
    mainTime?: number,
    mainPlusExtraTime?: number,
    completionTime?: number,
    reviewStars?: number,
    review?: string,
    note?: string
) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `UPDATE "blm-system"."BacklogEntries" 
       SET "Title" = $2, "Genre" = $3, "Platform" = $4, "Status" = $5, "Owned" = $6, "Interest" = $7, "ReleaseDate" = $8, "ImageLink" = $9, "MainTime" = $10, "MainPlusExtraTime" = $11, "CompletionTime" = $12, "ReviewStars" = $13, "Review" = $14, "Note" = $15, "UpdatedAt" = DATE_TRUNC('minute', CURRENT_TIMESTAMP) 
       WHERE "BacklogEntryID" = $1 
       RETURNING *`,
            [backlogEntryID, title, genre, platform, status, owned, interest, releaseDate || null, imageLink || null, mainTime || null, mainPlusExtraTime || null, completionTime || null, reviewStars || null, review || null, note || null]
        )
        return result.rows[0] as BacklogEntryRow
    } catch (error) {
        console.error('Error updating backlog entry:', error)
        throw error
    } finally {
        client.release()
    }
}


import type { Pool } from "pg";
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

export async function createUser(pool: Pool, username: string, email: string, passwordHash: string, steamId?: string) {
    const query = 'INSERT INTO "blm-system"."Users" ("Username", "Email", "PasswordHash", "SteamId") VALUES ($1, $2, $3, $4) RETURNING *'
    try {
        const result = await pool.query(query, [username, email, passwordHash, steamId])
        return result.rows[0]
    } catch (error) {
        console.error('Error creating user:', error)
        throw error
    }
}

export async function createGame(pool: Pool, title: string, genre: string, platform: string, releaseDate?: Date, imageLink?: string, howLongToBeat?: number[]) {
    const query = 'INSERT INTO "blm-system"."Games" ("Title", "Genre", "Platform", "ReleaseDate", "ImageLink", "HowLongToBeat") VALUES ($1, $2, $3, $4, $5, $6) RETURNING *'
    try {
        const result = await pool.query(query, [title, genre, platform, releaseDate || null, imageLink || null, howLongToBeat || null])
        return result.rows[0]
    } catch (error) {
        console.error('Error creating game:', error)
        throw error
    }
}

export async function createCategory(pool: Pool, userId: number, categoryName: string, color: string = '#000000', description: string = 'No description') {
    const query = 'INSERT INTO "blm-system"."Categories" ("UserID", "CategoryName", "Color", "Description") VALUES ($1, $2, $3, $4) RETURNING *'
    try {
        const result = await pool.query(query, [userId, categoryName, color, description])
        return result.rows[0]
    } catch (error) {
        console.error('Error creating category:', error)
        throw error
    }
}

export async function createBacklogEntry(pool: Pool, userId: number, gameId: number, status: string, owned: boolean, interest: number, reviewStars?: number, review?: string, note?: string) {
    const query = 'INSERT INTO "blm-system"."BacklogEntries" ("UserID", "GameID", "Status", "Owned", "Interest", "ReviewStars", "Review", "Note") VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *'
    try {
        const result = await pool.query(query, [userId, gameId, status, owned, interest, reviewStars || null, review || null, note || null])
        return result.rows[0]
    } catch (error) {
        console.error('Error creating backlog entry:', error)
        throw error
    }
}

export async function addCategoryToBacklogEntry(pool: Pool, categoryId: number, backlogEntryId: number) {
    const query = 'INSERT INTO "blm-system"."CategoryBacklogEntries" ("CategoryID", "BacklogEntryID") VALUES ($1, $2) RETURNING *'
    try {
        const result = await pool.query(query, [categoryId, backlogEntryId])
        return result.rows[0]
    } catch (error) {
        console.error('Error adding category to backlog entry:', error)
        throw error
    }
}
import type { Pool } from "pg";
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

export async function getAllUsers(pool: Pool) {
    const query = 'SELECT * FROM "blm-system"."Users"'
    try {
        const result = await pool.query(query)
        return result.rows
    } catch (error) {
        console.error('Error getting all users:', error)
        throw error
    }
}

export async function getUserById(pool: Pool, userId: number) {
    const query = 'SELECT * FROM "blm-system"."Users" WHERE "UserID" = $1'
    try {
        const result = await pool.query(query, [userId])
        return result.rows[0]
    } catch (error) {
        console.error('Error getting user by id:', error)
        throw error
    }
}

export async function getUserByUsername(pool: Pool, username: string) {
    const query = 'SELECT * FROM "blm-system"."Users" WHERE "Username" = $1'
    try {
        const result = await pool.query(query, [username])
        return result.rows[0]
    } catch (error) {
        console.error('Error getting user by username:', error)
        throw error
    }
}

export async function getGameById(pool: Pool, gameId: number) {
    const query = 'SELECT * FROM "blm-system"."Games" WHERE "GameID" = $1'
    try {
        const result = await pool.query(query, [gameId])
        return result.rows[0]
    } catch (error) {
        console.error('Error getting game by id:', error)
        throw error
    }
}

export async function getAllGames(pool: Pool) {
    const query = 'SELECT * FROM "blm-system"."Games"'
    try {
        const result = await pool.query(query)
        return result.rows
    } catch (error) {
        console.error('Error getting all games:', error)
        throw error
    }
}

export async function getCategoriesByUser(pool: Pool, userId: number) {
    const query = 'SELECT * FROM "blm-system"."Categories" WHERE "UserID" = $1'
    try {
        const result = await pool.query(query, [userId])
        return result.rows
    } catch (error) {
        console.error('Error getting categories:', error)
        throw error
    }
}

export async function getBacklogEntriesByUser(pool: Pool, userId: number) {
    const query = 'SELECT * FROM "blm-system"."BacklogEntries" WHERE "UserID" = $1'
    try {
        const result = await pool.query(query, [userId])
        return result.rows
    } catch (error) {
        console.error('Error getting backlog entries:', error)
        throw error
    }
}

export async function getBacklogEntryById(pool: Pool, backlogEntryId: number) {
    const query = 'SELECT * FROM "blm-system"."BacklogEntries" WHERE "BacklogEntryID" = $1'
    try {
        const result = await pool.query(query, [backlogEntryId])
        return result.rows[0]
    } catch (error) {
        console.error('Error getting backlog entry:', error)
        throw error
    }
}

export async function getBacklogEntriesByStatus(pool: Pool, userId: number, status: string) {
    const query = 'SELECT * FROM "blm-system"."BacklogEntries" WHERE "UserID" = $1 AND "Status" = $2'
    try {
        const result = await pool.query(query, [userId, status])
        return result.rows
    } catch (error) {
        console.error('Error getting backlog entries by status:', error)
        throw error
    }
}

export async function getCategoriesForBacklogEntry(pool: Pool, backlogEntryId: number) {
    const query = `SELECT c.* FROM "blm-system"."Categories" c
                   JOIN "blm-system"."CategoryBacklogEntries" cbe ON c."CategoryID" = cbe."CategoryID"
                   WHERE cbe."BacklogEntryID" = $1`
    try {
        const result = await pool.query(query, [backlogEntryId])
        return result.rows
    } catch (error) {
        console.error('Error getting categories for backlog entry:', error)
        throw error
    }
}

export async function getBacklogEntriesForCategory(pool: Pool, categoryId: number) {
    const query = `SELECT c.* FROM "blm-system"."BacklogEntries" c
                   JOIN "blm-system"."CategoryBacklogEntries" cbe ON c."BacklogEntryID" = cbe."BacklogEntryID"
                   WHERE cbe."CategoryID" = $1`
    try {
        const result = await pool.query(query, [categoryId])
        return result.rows
    } catch (error) {
        console.error('Error getting categories for backlog entry:', error)
        throw error
    }
}
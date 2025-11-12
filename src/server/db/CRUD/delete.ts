import { Pool } from 'pg'
import type {UserRow} from "~/server/db/types";
import type {CategoryRow} from "~/server/db/types";
import type {BacklogEntryRow} from "~/server/db/types";
import type {GameRow} from "~/server/db/types";
import type {BacklogCategoryRow} from "~/server/db/types";

export const deleteUser = async (pool: Pool, userID: number) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `DELETE FROM "blm-system"."Users"
             WHERE "UserID" = $1
             RETURNING *`,
            [userID]
        )
        return result.rows[0] as UserRow
    } catch (error) {
        console.error('Error deleting user:', error)
        throw error
    } finally {
        client.release()
    }
}

export const deleteCategory = async (pool: Pool, categoryID: number) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `DELETE FROM "blm-system"."Categories"
             WHERE "CategoryID" = $1
             RETURNING *`,
            [categoryID]
        )
        return result.rows[0] as CategoryRow
    } catch (error) {
        console.error('Error deleting category:', error)
        throw error
    } finally {
        client.release()
    }
}

export const deleteBacklogEntry = async (pool: Pool, backlogEntryID: number) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `DELETE FROM "blm-system"."BacklogEntries"
             WHERE "BacklogEntryID" = $1
             RETURNING *`,
            [backlogEntryID]
        )
        return result.rows[0] as BacklogEntryRow
    } catch (error) {
        console.error('Error deleting backlog entry:', error)
        throw error
    } finally {
        client.release()
    }
}

export const deleteGame = async (pool: Pool, gameID: number) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `DELETE FROM "blm-system"."Games"
             WHERE "GameID" = $1
             RETURNING *`,
            [gameID]
        )
        return result.rows[0] as GameRow
    } catch (error) {
        console.error('Error deleting game:', error)
        throw error
    } finally {
        client.release()
    }
}

export const removeBacklogEntryFromCategory = async (
    pool: Pool,
    categoryID: number,
    backlogEntryID: number
) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `DELETE FROM "blm-system"."CategoryBacklogEntries"
             WHERE "CategoryID" = $1 AND "BacklogEntryID" = $2
             RETURNING *`,
            [categoryID, backlogEntryID]
        )
        return result.rows[0] as BacklogCategoryRow
    } catch (error) {
        console.error('Error removing backlog entry from category:', error)
        throw error
    } finally {
        client.release()
    }
}

export const deleteCategoryBacklogEntries = async (pool: Pool, categoryID: number) => {
    const client = await pool.connect()
    try {
        const result = await client.query(
            `DELETE FROM "blm-system"."CategoryBacklogEntries"
             WHERE "CategoryID" = $1
             RETURNING *`,
            [categoryID]
        )
        return result.rows[0] as BacklogCategoryRow
    } catch (error) {
        console.error('Error deleting backlog entries from category:', error)
        throw error
    } finally {
        client.release()
    }
}
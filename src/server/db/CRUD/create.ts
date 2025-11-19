import type { Pool } from "pg";

export async function createUser(pool: Pool, username: string, email: string, passwordHash: string) {
    const query = 'INSERT INTO "blm-system"."Users" ("Username", "Email", "PasswordHash") VALUES ($1, $2, $3) RETURNING *'
    try {
        const result = await pool.query(query, [username, email, passwordHash])
        return result.rows[0]
    } catch (error) {
        console.error('Error creating user:', error)
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

export async function createBacklogEntry(pool: Pool, userId: number, title: string, genre: string, platform: string, status: string, owned: boolean, interest: number, releaseDate?: Date, imageLink?: string, howLongToBeat?: string, reviewStars?: number, review?: string, note?: string) {
    const query = 'INSERT INTO "blm-system"."BacklogEntries" ("UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest", "ReleaseDate", "ImageLink", "HowLongToBeat", "ReviewStars", "Review", "Note") VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13) RETURNING *'
    try {
        const result = await pool.query(query, [userId, title, genre, platform, status, owned, interest, releaseDate || null, imageLink || null, howLongToBeat || null, reviewStars || null, review || null, note || null])
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
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest'
import { Pool } from 'pg'
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql'
import fs from 'fs'
import path from 'path'
import { createUser, createCategory, createBacklogEntry, addCategoryToBacklogEntry } from '~/server/db/CRUD/create'
import {
    getAllUsers,
    getCategoriesByUser,
    getBacklogEntriesByUser,
    getCategoriesForBacklogEntry,
    getBacklogEntriesForCategory
} from "~/server/db/CRUD/read"
import {
    deleteUser,
    deleteCategory,
    deleteBacklogEntry,
    removeBacklogEntryFromCategory,
    deleteCategoryBacklogEntries
} from "~/server/db/CRUD/delete"

describe('Database Delete Operations', () => {
    let postgresContainer: StartedPostgreSqlContainer
    let postgresPool: Pool

    beforeAll(async () => {
        postgresContainer = await new PostgreSqlContainer('postgres:16')
            .withDatabase('backlog-manager-db')
            .withUsername('testuser')
            .withPassword('testpass')
            .start()

        postgresPool = new Pool({
            user: 'testuser',
            password: 'testpass',
            host: postgresContainer.getHost(),
            port: postgresContainer.getPort(),
            database: 'backlog-manager-db'
        })

        const sql = fs.readFileSync(path.resolve(__dirname, '../postgres/backlogmanagerdb-init.sql'), 'utf-8')

        await postgresPool.query(sql)
    }, 60000)

    afterAll(async () => {
        await postgresPool.end()
        await postgresContainer.stop()
    })

    describe('User Delete Operations', () => {
        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await createUser(postgresPool, "John Doe", "john@doe.com", "password123")
            await createUser(postgresPool, "Jane Doe", "jane@doe.com", "password456")
        })

        it('should delete user and return deleted user data', async () => {
            const deletedUser = await deleteUser(postgresPool, 1)

            expect(deletedUser.UserID).toBe('1')
            expect(deletedUser.Username).toBe('John Doe')
            expect(deletedUser.Email).toBe('john@doe.com')
            expect(deletedUser.PasswordHash).toBe('password123')
        })

        it('should remove user from database', async () => {
            await deleteUser(postgresPool, 1)

            const users = await getAllUsers(postgresPool)
            expect(users).toHaveLength(1)
            expect(users[0].Username).toBe('Jane Doe')
        })

        it('should return undefined when deleting non-existent user', async () => {
            const deletedUser = await deleteUser(postgresPool, 999)
            expect(deletedUser).toBeUndefined()
        })

        it('should cascade delete related data when user is deleted', async () => {
            await createCategory(postgresPool, 1, "Action", "#FF0000")
            await createBacklogEntry(postgresPool, 1, "Test Game", "RPG", "PC", "Not Started", false, 3)

            await deleteUser(postgresPool, 1)

            const categories = await getCategoriesByUser(postgresPool, 1)
            expect(categories).toHaveLength(0)

            const entries = await getBacklogEntriesByUser(postgresPool, 1)
            expect(entries).toHaveLength(0)
        })
    })

    describe('Category Delete Operations', () => {
        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Categories" RESTART IDENTITY CASCADE')
            await createUser(postgresPool, "John Doe", "john@doe.com", "password123")
            await createCategory(postgresPool, 1, "Action", "#FF0000", "Action games")
            await createCategory(postgresPool, 1, "Adventure", "#00FF00")
        })

        it('should delete category and return deleted category data', async () => {
            const deletedCategory = await deleteCategory(postgresPool, 1)

            expect(deletedCategory.CategoryID).toBe('1')
            expect(deletedCategory.CategoryName).toBe('Action')
            expect(deletedCategory.Color).toBe('#FF0000')
            expect(deletedCategory.Description).toBe('Action games')
        })

        it('should remove category from database', async () => {
            await deleteCategory(postgresPool, 1)

            const categories = await getCategoriesByUser(postgresPool, 1)
            expect(categories).toHaveLength(1)
            expect(categories[0].CategoryName).toBe('Adventure')
        })

        it('should return undefined when deleting non-existent category', async () => {
            const deletedCategory = await deleteCategory(postgresPool, 999)
            expect(deletedCategory).toBeUndefined()
        })

        it('should cascade delete CategoryBacklogEntries relationships', async () => {
            await createBacklogEntry(postgresPool, 1, "Test Game", "RPG", "PC", "Not Started", false, 3)
            await addCategoryToBacklogEntry(postgresPool, 1, 1)

            const categoriesBefore = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categoriesBefore).toHaveLength(1)

            await deleteCategory(postgresPool, 1)

            const categoriesAfter = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categoriesAfter).toHaveLength(0)
        })
    })

    describe('Backlog Entry Delete Operations', () => {
        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."BacklogEntries" RESTART IDENTITY CASCADE')

            await createUser(postgresPool, "John Doe", "john@doe.com", "password123")
            await createBacklogEntry(postgresPool, 1, "Elden Ring", "RPG", "PC", "Not Started", false, 3, null, null, null, null, null, null, null,  "Note 1")
            await createBacklogEntry(postgresPool, 1, "Hollow Knight", "Metroidvania", "PC", "In Progress", true, 4, new Date(), "Great game.jpg", 50, 100, 150, 5, "Great game", "Note 2")
        })

        it('should delete backlog entry and return deleted entry data', async () => {
            const deletedEntry = await deleteBacklogEntry(postgresPool, 1)

            expect(deletedEntry.BacklogEntryID).toBe('1')
            expect(deletedEntry.UserID).toBe('1')
            expect(deletedEntry.Title).toBe('Elden Ring')
            expect(deletedEntry.Genre).toBe('RPG')
            expect(deletedEntry.Platform).toBe('PC')
            expect(deletedEntry.Status).toBe('Not Started')
            expect(deletedEntry.Owned).toBe(false)
            expect(deletedEntry.Interest).toBe(3)
            expect(deletedEntry.Note).toBe('Note 1')
        })

        it('should remove entry with GameID references', async () => {
            await deleteBacklogEntry(postgresPool, 1)

            const entries = await getBacklogEntriesByUser(postgresPool, 1)
            expect(entries).toHaveLength(1)
            expect(entries[0].Title).toBe('Hollow Knight')
        })

        it('should return undefined when deleting non-existent entry', async () => {
            const deletedEntry = await deleteBacklogEntry(postgresPool, 999)
            expect(deletedEntry).toBeUndefined()
        })

        it('should cascade delete CategoryBacklogEntries relationships', async () => {
            await createCategory(postgresPool, 1, "Action", "#FF0000")
            await addCategoryToBacklogEntry(postgresPool, 1, 1)

            const categoriesBefore = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categoriesBefore).toHaveLength(1)

            await deleteBacklogEntry(postgresPool, 1)

            const categoriesAfter = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categoriesAfter).toHaveLength(0)
        })

        it('should delete entry with all optional fields', async () => {
            const deletedEntry = await deleteBacklogEntry(postgresPool, 2)

            expect(deletedEntry.BacklogEntryID).toBe('2')
            expect(deletedEntry.ReviewStars).toBe(5)
            expect(deletedEntry.Review).toBe('Great game')
            expect(deletedEntry.Note).toBe('Note 2')
        })
    })

    describe('CategoryBacklogEntry Delete Operations', () => {
        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Categories" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."BacklogEntries" RESTART IDENTITY CASCADE')

            await createUser(postgresPool, "John Doe", "john@doe.com", "password123")
            await createBacklogEntry(postgresPool, 1, "Elden Ring", "RPG", "PC", "Not Started", false, 3)
            await createBacklogEntry(postgresPool, 1, "Hollow Knight", "Metroidvania", "PC", "In Progress", true, 4)
            await createCategory(postgresPool, 1, "Action", "#FF0000")
            await createCategory(postgresPool, 1, "Adventure", "#00FF00")

            await addCategoryToBacklogEntry(postgresPool, 1, 1)
            await addCategoryToBacklogEntry(postgresPool, 2, 1)
            await addCategoryToBacklogEntry(postgresPool, 1, 2)
        })

        it('should remove single backlog entry from category', async () => {
            const removed = await removeBacklogEntryFromCategory(postgresPool, 1, 1)

            expect(removed.CategoryID).toBe('1')
            expect(removed.BacklogEntryID).toBe('1')

            const categories = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categories).toHaveLength(1)
            expect(categories[0].CategoryID).toBe('2')
        })

        it('should not affect other relationships when removing one', async () => {
            await removeBacklogEntryFromCategory(postgresPool, 1, 1)

            const categoriesForEntry2 = await getCategoriesForBacklogEntry(postgresPool, 2)
            expect(categoriesForEntry2).toHaveLength(1)
            expect(categoriesForEntry2[0].CategoryID).toBe('1')

            const entriesForCategory2 = await getBacklogEntriesForCategory(postgresPool, 2)
            expect(entriesForCategory2).toHaveLength(1)
        })

        it('should return undefined when removing non-existent relationship', async () => {
            const removed = await removeBacklogEntryFromCategory(postgresPool, 999, 999)
            expect(removed).toBeUndefined()
        })

        it('should delete all backlog entries from a category', async () => {
            const deleted = await deleteCategoryBacklogEntries(postgresPool, 1)

            expect(deleted.CategoryID).toBe('1')

            const entriesForCategory1 = await getBacklogEntriesForCategory(postgresPool, 1)
            expect(entriesForCategory1).toHaveLength(0)

            const entriesForCategory2 = await getBacklogEntriesForCategory(postgresPool, 2)
            expect(entriesForCategory2).toHaveLength(1)
        })

        it('should return undefined when deleting from category with no entries', async () => {
            await createCategory(postgresPool, 1, "Empty Category", "#0000FF")

            const deleted = await deleteCategoryBacklogEntries(postgresPool, 3)
            expect(deleted).toBeUndefined()
        })

        it('should handle removing last relationship from backlog entry', async () => {
            await removeBacklogEntryFromCategory(postgresPool, 1, 2)

            const categories = await getCategoriesForBacklogEntry(postgresPool, 2)
            expect(categories).toHaveLength(0)
        })

        it('should handle deleting all entries when category has multiple entries', async () => {
            const deleted = await deleteCategoryBacklogEntries(postgresPool, 1)

            expect(deleted).toBeDefined()

            const entriesForCategory1 = await getBacklogEntriesForCategory(postgresPool, 1)
            expect(entriesForCategory1).toHaveLength(0)
        })
    })
})
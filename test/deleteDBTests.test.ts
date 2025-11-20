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
            await createUser(postgresPool, { username: "John Doe", email: "john@doe.com", passwordHash: "password123" })
            await createUser(postgresPool, { username: "Jane Doe", email: "jane@doe.com", passwordHash: "password456" })
        })

        it('should delete user and return deleted user data', async () => {
            const deletedUser = await deleteUser(postgresPool, 1)

            expect(deletedUser.id).toBe(1)
            expect(deletedUser.name).toBe('John Doe')
            expect(deletedUser.email).toBe('john@doe.com')
            expect(deletedUser.passwordHash).toBe('password123')
        })

        it('should remove user from database', async () => {
            await deleteUser(postgresPool, 1)

            const users = await getAllUsers(postgresPool)
            expect(users).toHaveLength(1)
            expect(users[0]!.name).toBe('Jane Doe')
        })

        it('should throw NotFoundError when deleting non-existent user', async () => {
            await expect(deleteUser(postgresPool, 999)).rejects.toThrow()
        })

        it('should cascade delete related data when user is deleted', async () => {
            await createCategory(postgresPool, { userId: 1, categoryName: "Action", color: "#FF0000" })
            await createBacklogEntry(postgresPool, { userId: 1, title: "Test Game", genre: "RPG", platform: "PC", status: "Not Started", owned: false, interest: 3 })

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
            await createUser(postgresPool, { username: "John Doe", email: "john@doe.com", passwordHash: "password123" })
            await createCategory(postgresPool, { userId: 1, categoryName: "Action", color: "#FF0000", description: "Action games" })
            await createCategory(postgresPool, { userId: 1, categoryName: "Adventure", color: "#00FF00" })
        })

        it('should delete category and return deleted category data', async () => {
            const deletedCategory = await deleteCategory(postgresPool, 1)

            expect(deletedCategory.categoryID).toBe(1)
            expect(deletedCategory.name).toBe('Action')
            expect(deletedCategory.color).toBe('#FF0000')
            expect(deletedCategory.description).toBe('Action games')
        })

        it('should remove category from database', async () => {
            await deleteCategory(postgresPool, 1)

            const categories = await getCategoriesByUser(postgresPool, 1)
            expect(categories).toHaveLength(1)
            expect(categories[0]!.name).toBe('Adventure')
        })

        it('should throw NotFoundError when deleting non-existent category', async () => {
            await expect(deleteCategory(postgresPool, 999)).rejects.toThrow()
        })

        it('should cascade delete CategoryBacklogEntries relationships', async () => {
            await createBacklogEntry(postgresPool, { userId: 1, title: "Test Game", genre: "RPG", platform: "PC", status: "Not Started", owned: false, interest: 3 })
            await addCategoryToBacklogEntry(postgresPool, { categoryId: 1, backlogEntryId: 1 })

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

            await createUser(postgresPool, { username: "John Doe", email: "john@doe.com", passwordHash: "password123" })
            await createBacklogEntry(postgresPool, { userId: 1, title: "Elden Ring", genre: "RPG", platform: "PC", status: "Not Started", owned: false, interest: 3, note: "Note 1" })
            await createBacklogEntry(postgresPool, { userId: 1, title: "Hollow Knight", genre: "Metroidvania", platform: "PC", status: "In Progress", owned: true, interest: 4, releaseDate: new Date(), imageLink: "Great game.jpg", mainTime: 50, mainPlusExtraTime: 100, completionTime: 150, reviewStars: 5, review: "Great game", note: "Note 2" })
        })

        it('should delete backlog entry and return deleted entry data', async () => {
            const deletedEntry = await deleteBacklogEntry(postgresPool, 1)

            expect(deletedEntry.backlogEntryID).toBe(1)
            expect(deletedEntry.userID).toBe(1)
            expect(deletedEntry.title).toBe('Elden Ring')
            expect(deletedEntry.genre).toBe('RPG')
            expect(deletedEntry.platform).toBe('PC')
            expect(deletedEntry.status).toBe('Not Started')
            expect(deletedEntry.owned).toBe(false)
            expect(deletedEntry.interest).toBe(3)
            expect(deletedEntry.note).toBe('Note 1')
        })

        it('should remove entry with GameID references', async () => {
            await deleteBacklogEntry(postgresPool, 1)

            const entries = await getBacklogEntriesByUser(postgresPool, 1)
            expect(entries).toHaveLength(1)
            expect(entries[0]!.title).toBe('Hollow Knight')
        })

        it('should throw NotFoundError when deleting non-existent entry', async () => {
            await expect(deleteBacklogEntry(postgresPool, 999)).rejects.toThrow()
        })

        it('should cascade delete CategoryBacklogEntries relationships', async () => {
            await createCategory(postgresPool, { userId: 1, categoryName: "Action", color: "#FF0000" })
            await addCategoryToBacklogEntry(postgresPool, { categoryId: 1, backlogEntryId: 1 })

            const categoriesBefore = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categoriesBefore).toHaveLength(1)

            await deleteBacklogEntry(postgresPool, 1)

            const categoriesAfter = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categoriesAfter).toHaveLength(0)
        })

        it('should delete entry with all optional fields', async () => {
            const deletedEntry = await deleteBacklogEntry(postgresPool, 2)

            expect(deletedEntry.backlogEntryID).toBe(2)
            expect(deletedEntry.reviewStars).toBe(5)
            expect(deletedEntry.review).toBe('Great game')
            expect(deletedEntry.note).toBe('Note 2')
        })
    })

    describe('CategoryBacklogEntry Delete Operations', () => {
        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Categories" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."BacklogEntries" RESTART IDENTITY CASCADE')

            await createUser(postgresPool, { username: "John Doe", email: "john@doe.com", passwordHash: "password123" })
            await createBacklogEntry(postgresPool, { userId: 1, title: "Elden Ring", genre: "RPG", platform: "PC", status: "Not Started", owned: false, interest: 3 })
            await createBacklogEntry(postgresPool, { userId: 1, title: "Hollow Knight", genre: "Metroidvania", platform: "PC", status: "In Progress", owned: true, interest: 4 })
            await createCategory(postgresPool, { userId: 1, categoryName: "Action", color: "#FF0000" })
            await createCategory(postgresPool, { userId: 1, categoryName: "Adventure", color: "#00FF00" })

            await addCategoryToBacklogEntry(postgresPool, { categoryId: 1, backlogEntryId: 1 })
            await addCategoryToBacklogEntry(postgresPool, { categoryId: 2, backlogEntryId: 1 })
            await addCategoryToBacklogEntry(postgresPool, { categoryId: 1, backlogEntryId: 2 })
        })

        it('should remove single backlog entry from category', async () => {
            const removed = await removeBacklogEntryFromCategory(postgresPool, { categoryId: 1, backlogEntryId: 1 })

            expect(removed.categoryID).toBe(1)
            expect(removed.backlogEntryID).toBe(1)

            const categories = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categories).toHaveLength(1)
            expect(categories[0]!.categoryID).toBe(2)
        })

        it('should not affect other relationships when removing one', async () => {
            await removeBacklogEntryFromCategory(postgresPool, { categoryId: 1, backlogEntryId: 1 })

            const categoriesForEntry2 = await getCategoriesForBacklogEntry(postgresPool, 2)
            expect(categoriesForEntry2).toHaveLength(1)
            expect(categoriesForEntry2[0]!.categoryID).toBe(1)

            const entriesForCategory2 = await getBacklogEntriesForCategory(postgresPool, 2)
            expect(entriesForCategory2).toHaveLength(1)
        })

        it('should throw NotFoundError when removing non-existent relationship', async () => {
            await expect(removeBacklogEntryFromCategory(postgresPool, { categoryId: 999, backlogEntryId: 999 })).rejects.toThrow()
        })

        it('should delete all backlog entries from a category', async () => {
            const deleted = await deleteCategoryBacklogEntries(postgresPool, 1)

            expect(deleted).toBeInstanceOf(Array)
            expect(deleted.length).toBeGreaterThan(0)

            const entriesForCategory1 = await getBacklogEntriesForCategory(postgresPool, 1)
            expect(entriesForCategory1).toHaveLength(0)

            const entriesForCategory2 = await getBacklogEntriesForCategory(postgresPool, 2)
            expect(entriesForCategory2).toHaveLength(1)
        })

        it('should return empty array when deleting from category with no entries', async () => {
            await createCategory(postgresPool, { userId: 1, categoryName: "Empty Category", color: "#0000FF" })

            const deleted = await deleteCategoryBacklogEntries(postgresPool, 3)
            expect(deleted).toBeInstanceOf(Array)
            expect(deleted).toHaveLength(0)
        })

        it('should handle removing last relationship from backlog entry', async () => {
            await removeBacklogEntryFromCategory(postgresPool, { categoryId: 1, backlogEntryId: 2 })

            const categories = await getCategoriesForBacklogEntry(postgresPool, 2)
            expect(categories).toHaveLength(0)
        })

        it('should handle deleting all entries when category has multiple entries', async () => {
            const deleted = await deleteCategoryBacklogEntries(postgresPool, 1)

            expect(deleted).toBeInstanceOf(Array)
            expect(deleted.length).toBeGreaterThan(0)

            const entriesForCategory1 = await getBacklogEntriesForCategory(postgresPool, 1)
            expect(entriesForCategory1).toHaveLength(0)
        })
    })
})
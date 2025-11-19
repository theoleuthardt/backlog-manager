import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { Pool } from 'pg'
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql'
import fs from 'fs'
import path from 'path'
import { createUser, createCategory, createBacklogEntry, addCategoryToBacklogEntry } from '~/server/db/CRUD/create'
import {
    getAllUsers,
    getUserById,
    getUserByUsername,
    getCategoriesByUser,
    getBacklogEntriesByUser,
    getBacklogEntryById,
    getBacklogEntriesByStatus,
    getCategoriesForBacklogEntry, getBacklogEntriesForCategory
} from "~/server/db/CRUD/read"

describe('Database Read Operations', () => {
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

        await createUser(postgresPool, "John Doe", "john@doe", "1234567890")
        await createUser(postgresPool, "Jane Doe", "jane@doe", "1234567890")

        await createCategory(postgresPool, 1, "Action", "#FF0000", "A game with action and adventure")
        await createCategory(postgresPool, 1, "Adventure", "#00FF00")
        await createCategory(postgresPool, 2, "Indie", "#0000FF")

        await createBacklogEntry(postgresPool, 1, "Elden Ring", "RPG", "PC", "Not Started", true, 2, new Date(), "Pictures/EldenRing.jpg", "", 4, "This is a review", "This is a note")
        await createBacklogEntry(postgresPool, 1, "Hollow Knight", "Metroidvania", "PC", "In Progress", false, 3)
        await createBacklogEntry(postgresPool, 2, "Elden Ring", "RPG", "PC", "Completed", true, 7)

        await addCategoryToBacklogEntry(postgresPool, 1, 1)
        await addCategoryToBacklogEntry(postgresPool, 2, 1)

    }, 60000)

    afterAll(async () => {
        await postgresPool.end()
        await postgresContainer.stop()
    })

    describe('User Read Operations', () => {
        const now = new Date();
        now.setHours(now.getHours() - 2);
        now.setSeconds(0, 0)

        it('should get all users', async () => {
            const users = await getAllUsers(postgresPool)
            expect(users).toHaveLength(2)
            expect(users[0].Username).toBe('John Doe')
            expect(users[1].Username).toBe('Jane Doe')
        })

        it('should get user by id', async () => {
            const user = await getUserById(postgresPool, 1)
            expect(user).toEqual({ UserID: '1', Username: 'John Doe', Email: 'john@doe', PasswordHash: '1234567890', CreatedAt: now, UpdatedAt: now})
        })

        it('should get user by username', async () => {
            const user = await getUserByUsername(postgresPool, 'Jane Doe')
            expect(user.Username).toBe('Jane Doe')
            expect(user.Email).toBe('jane@doe')
        })
    })


    describe('Category Read Operations', () => {
        it('should get categories by user', async () => {
            const categories = await getCategoriesByUser(postgresPool, 1)
            expect(categories).toHaveLength(2)
            expect(categories[0].CategoryID).toBe('1')
            expect(categories[0].UserID).toBe('1')
            expect(categories[0].CategoryName).toBe('Action')
            expect(categories[0].Color).toBe('#FF0000')
            expect(categories[0].Description).toBe('A game with action and adventure')
        })

        it('should get categories for different user', async () => {
            const categories = await getCategoriesByUser(postgresPool, 2)
            expect(categories).toHaveLength(1)
            expect(categories[0].CategoryName).toBe('Indie')
        })
    })

    describe('Backlog Entry Read Operations', () => {

        const now = new Date();
        now.setHours(now.getHours() - 2);
        now.setSeconds(0, 0)

        it('should get backlog entries by user', async () => {
            const entries = await getBacklogEntriesByUser(postgresPool, 1)
            expect(entries).toHaveLength(2)
            expect(entries[0].BacklogEntryID).toBe('1')
            expect(entries[0].UserID).toBe('1')
            expect(entries[0].Title).toBe('Elden Ring')
            expect(entries[0].Genre).toBe('RPG')
            expect(entries[0].Platform).toBe('PC')
            expect(entries[0].Status).toBe('Not Started')
            expect(entries[0].Owned).toBe(true)
            expect(entries[0].Interest).toBe(2)
            expect(entries[0].ReviewStars).toBe(4)
            expect(entries[0].Review).toBe('This is a review')
            expect(entries[0].Note).toBe('This is a note')
            expect(entries[0].CreatedAt).toStrictEqual(now)
            expect(entries[0].UpdatedAt).toStrictEqual(now)
        })

        it('should get backlog entry by id', async () => {
            const entry = await getBacklogEntryById(postgresPool, 1)
            expect(entry.Status).toBe('Not Started')
        })

        it('should get backlog entries by status', async () => {
            const notStarted = await getBacklogEntriesByStatus(postgresPool, 1, 'Not Started')
            expect(notStarted).toHaveLength(1)
            expect(notStarted[0].Title).toBe("Elden Ring")

            const inProgress = await getBacklogEntriesByStatus(postgresPool, 1, 'In Progress')
            expect(inProgress).toHaveLength(1)
            expect(inProgress[0].Title).toBe("Hollow Knight")

            const completed = await getBacklogEntriesByStatus(postgresPool, 1, 'Completed')
            expect(completed).toHaveLength(0)
        })

        it('should get categories for backlog entry', async () => {
            const categories = await getCategoriesForBacklogEntry(postgresPool, 1)
            expect(categories).toHaveLength(2)
            expect(categories[0].CategoryName).toBe('Action')
            expect(categories[1].CategoryName).toBe('Adventure')
        })

        it('should return empty array for backlog entry without categories', async () => {
            const categories = await getCategoriesForBacklogEntry(postgresPool, 3)
            expect(categories).toHaveLength(0)
        })

        it('should get backlog entries for category with all fields', async () => {
            const backlogEntries = await getBacklogEntriesForCategory(postgresPool, 1)

            expect(backlogEntries).toHaveLength(1)

            expect(backlogEntries[0].BacklogEntryID).toBe('1')
            expect(backlogEntries[0].UserID).toBe('1')
            expect(backlogEntries[0].Title).toBe('Elden Ring')
            expect(backlogEntries[0].Status).toBe('Not Started')
        })

        it('should get multiple backlog entries for category', async () => {
            const backlogEntries = await getBacklogEntriesForCategory(postgresPool, 2)

            expect(backlogEntries).toHaveLength(1)
            expect(backlogEntries[0].BacklogEntryID).toBe('1')
            expect(backlogEntries[0].Title).toBe('Elden Ring')
        })

        it('should return empty array for category without backlog entries', async () => {
            const backlogEntries = await getBacklogEntriesForCategory(postgresPool, 3)
            expect(backlogEntries).toHaveLength(0)
        })
    })
})



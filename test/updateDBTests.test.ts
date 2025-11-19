import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest'
import { Pool } from 'pg'
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql'
import fs from 'fs'
import path from 'path'
import { createUser, createGame, createCategory, createBacklogEntry } from '~/server/db/CRUD/create'
import { getUserById, getGameById, getCategoriesByUser, getBacklogEntryById } from "~/server/db/CRUD/read"
import { updateUser, updateCategory, updateBacklogEntry, updateGame } from "~/server/db/CRUD/update"

describe('Database Update Operations', () => {
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

    describe('User Update Operations', () => {
        let userId: number

        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await createUser(postgresPool, "John Doe", "john@doe.com", "oldpassword123")
            userId = 1
        })

        it('should update user with all fields', async () => {
            const updatedUser = await updateUser(
                postgresPool,
                userId,
                "John Smith",
                "john@smith.com",
                "newpassword456"
            )

            expect(updatedUser.UserID).toBe('1')
            expect(updatedUser.Username).toBe('John Smith')
            expect(updatedUser.Email).toBe('john@smith.com')
            expect(updatedUser.PasswordHash).toBe('newpassword456')
            expect(updatedUser.UpdatedAt).toBeInstanceOf(Date)
        })

        it('should update only username', async () => {
            const updatedUser = await updateUser(
                postgresPool,
                userId,
                "Jane Doe",
                "john@doe.com",
                "oldpassword123"
            )

            expect(updatedUser.Username).toBe('Jane Doe')
            expect(updatedUser.Email).toBe('john@doe.com')
            expect(updatedUser.PasswordHash).toBe('oldpassword123')
        })

        it('should update UpdatedAt timestamp', async () => {
            const originalUser = await getUserById(postgresPool, userId)

            await new Promise(resolve => setTimeout(resolve, 1000))

            const updatedUser = await updateUser(
                postgresPool,
                userId,
                "Updated Name",
                "john@doe.com",
                "oldpassword123"
            )

            expect(new Date(updatedUser.UpdatedAt).getTime())
                .toBeGreaterThanOrEqual(new Date(originalUser.UpdatedAt).getTime())
        })
    })

    describe('Category Update Operations', () => {
        let categoryId: number

        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Categories" RESTART IDENTITY CASCADE')
            await createUser(postgresPool, "John Doe", "john@doe.com", "password123")
            await createCategory(postgresPool, 1, "Action", "#FF0000", "Action games")
            categoryId = 1
        })

        it('should update category with all fields', async () => {
            const updatedCategory = await updateCategory(
                postgresPool,
                categoryId,
                "Adventure",
                "#00FF00",
                "Adventure games description"
            )

            expect(updatedCategory.CategoryID).toBe('1')
            expect(updatedCategory.CategoryName).toBe('Adventure')
            expect(updatedCategory.Color).toBe('#00FF00')
            expect(updatedCategory.Description).toBe('Adventure games description')
            expect(updatedCategory.UpdatedAt).toBeInstanceOf(Date)
        })

        it('should update only category name', async () => {
            const updatedCategory = await updateCategory(
                postgresPool,
                categoryId,
                "RPG",
                "#FF0000",
                "Action games"
            )

            expect(updatedCategory.CategoryName).toBe('RPG')
            expect(updatedCategory.Color).toBe('#FF0000')
            expect(updatedCategory.Description).toBe('Action games')
        })

        it('should update description to empty string', async () => {
            const updatedCategory = await updateCategory(
                postgresPool,
                categoryId,
                "Action",
                "#FF0000",
                ""
            )

            expect(updatedCategory.Description).toBe('')
        })
    })

    describe('Game Update Operations', () => {
        let gameId: number

        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Games" RESTART IDENTITY CASCADE')
            await createGame(
                postgresPool,
                "Elden Ring",
                "RPG",
                "PC",
                new Date('2022-02-25'),
                "old-image.jpg",
                [50, 100, 150]
            )
            gameId = 1
        })

        it('should update game with all fields', async () => {
            const newDate = new Date('2023-01-01')
            const updatedGame = await updateGame(
                postgresPool,
                gameId,
                "Elden Ring: Shadow of the Erdtree",
                "Action RPG",
                "Multi-platform",
                newDate,
                "new-image.jpg",
                [60, 120, 180]
            )

            expect(updatedGame.GameID).toBe('1')
            expect(updatedGame.Title).toBe('Elden Ring: Shadow of the Erdtree')
            expect(updatedGame.Genre).toBe('Action RPG')
            expect(updatedGame.Platform).toBe('Multi-platform')
            expect(updatedGame.ReleaseDate).toBeInstanceOf(Date)
            expect(updatedGame.ImageLink).toBe('new-image.jpg')
            expect(updatedGame.HowLongToBeat).toEqual([60, 120, 180])
            expect(updatedGame.UpdatedAt).toBeInstanceOf(Date)
        })

        it('should update only title and genre', async () => {
            const updatedGame = await updateGame(
                postgresPool,
                gameId,
                "Dark Souls 4",
                "Souls-like",
                "PC",
                new Date('2022-02-25'),
                "old-image.jpg",
                [50, 100, 150]
            )

            expect(updatedGame.Title).toBe('Dark Souls 4')
            expect(updatedGame.Genre).toBe('Souls-like')
            expect(updatedGame.Platform).toBe('PC')
        })

        it('should update with null optional fields', async () => {
            const updatedGame = await updateGame(
                postgresPool,
                gameId,
                "Minimal Game",
                "Indie",
                "PC"
            )

            expect(updatedGame.Title).toBe('Minimal Game')
            expect(updatedGame.Genre).toBe('Indie')
            expect(updatedGame.ReleaseDate).toBeNull()
            expect(updatedGame.ImageLink).toBeNull()
            expect(updatedGame.HowLongToBeat).toBeNull()
        })

        it('should clear optional fields by passing undefined', async () => {
            const updatedGame = await updateGame(
                postgresPool,
                gameId,
                "Elden Ring",
                "RPG",
                "PC",
                undefined,
                undefined,
                undefined
            )

            expect(updatedGame.ReleaseDate).toBeNull()
            expect(updatedGame.ImageLink).toBeNull()
            expect(updatedGame.HowLongToBeat).toBeNull()
        })
    })

    describe('Backlog Entry Update Operations', () => {
        let backlogEntryId: number

        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Games" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."BacklogEntries" RESTART IDENTITY CASCADE')

            await createUser(postgresPool, "John Doe", "john@doe.com", "password123")
            await createGame(postgresPool, "Elden Ring", "RPG", "PC", new Date())
            await createBacklogEntry(
                postgresPool,
                1,
                1,
                "Not Started",
                false,
                3,
                null,
                null,
                "Initial note"
            )
            backlogEntryId = 1
        })

        it('should update backlog entry with all fields', async () => {
            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "Completed",
                true,
                5,
                5,
                "Amazing game!",
                "Finished after 100 hours"
            )

            expect(updatedEntry.BacklogEntryID).toBe('1')
            expect(updatedEntry.Status).toBe('Completed')
            expect(updatedEntry.Owned).toBe(true)
            expect(updatedEntry.Interest).toBe(5)
            expect(updatedEntry.ReviewStars).toBe(5)
            expect(updatedEntry.Review).toBe('Amazing game!')
            expect(updatedEntry.Note).toBe('Finished after 100 hours')
            expect(updatedEntry.UpdatedAt).toBeInstanceOf(Date)
        })

        it('should update status from Not Started to In Progress', async () => {
            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "In Progress",
                false,
                3
            )

            expect(updatedEntry.Status).toBe('In Progress')
            expect(updatedEntry.ReviewStars).toBeNull()
            expect(updatedEntry.Review).toBeNull()
        })

        it('should update owned status', async () => {
            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "Not Started",
                true,
                3
            )

            expect(updatedEntry.Owned).toBe(true)
        })

        it('should update interest level', async () => {
            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "Not Started",
                false,
                5
            )

            expect(updatedEntry.Interest).toBe(5)
        })

        it('should add review and rating to entry without them', async () => {
            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "Completed",
                true,
                5,
                4,
                "Good game but has some flaws",
                "Completed main story"
            )

            expect(updatedEntry.Status).toBe('Completed')
            expect(updatedEntry.ReviewStars).toBe(4)
            expect(updatedEntry.Review).toBe('Good game but has some flaws')
            expect(updatedEntry.Note).toBe('Completed main story')
        })

        it('should clear optional fields', async () => {
            await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "Completed",
                true,
                5,
                5,
                "Great game",
                "Some notes"
            )

            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "Completed",
                true,
                5
            )

            expect(updatedEntry.ReviewStars).toBeNull()
            expect(updatedEntry.Review).toBeNull()
            expect(updatedEntry.Note).toBeNull()
        })

        it('should update UpdatedAt timestamp', async () => {
            const originalEntry = await getBacklogEntryById(postgresPool, backlogEntryId)

            await new Promise(resolve => setTimeout(resolve, 1000))

            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "In Progress",
                false,
                4
            )

            expect(new Date(updatedEntry.UpdatedAt).getTime())
                .toBeGreaterThanOrEqual(new Date(originalEntry.UpdatedAt).getTime())
        })
    })
})
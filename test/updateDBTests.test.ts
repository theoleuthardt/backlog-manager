import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest'
import { Pool } from 'pg'
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql'
import fs from 'fs'
import path from 'path'
import { createUser, createCategory, createBacklogEntry } from '~/server/db/CRUD/create'
import { getUserById, getCategoriesByUser, getBacklogEntryById, getUserByEmail } from "~/server/db/CRUD/read"
import { updateUserByEmail, updateCategory, updateBacklogEntry } from "~/server/db/CRUD/update"


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
        let email: string

        beforeEach(async () => {
            email = "john@doe.com"
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await createUser(postgresPool, "John Doe", email, "oldpassword123", "12345")

        })


        it('should update user with all fields', async () => {
            const updatedUser = await updateUserByEmail(
                postgresPool,
                email,
                "john_smith",
                "newpassword456",
                "123456"
            )

            expect(updatedUser.Username).toBe('john_smith')
            expect(updatedUser.Email).toBe(email)
            expect(updatedUser.PasswordHash).toBe('newpassword456')
            expect(updatedUser.UpdatedAt).toBeInstanceOf(Date)
            expect(updatedUser.SteamId).toBe('123456')
        })

        it('should update only username', async () => {
            const updatedUser = await updateUserByEmail(
                postgresPool,
                email,
                "new_username",
                "oldpassword123",
                "12345"	
            )

            expect(updatedUser.Username).toBe('new_username')
            expect(updatedUser.Email).toBe(email)
            expect(updatedUser.PasswordHash).toBe('oldpassword123')
            expect(updatedUser.UpdatedAt).toBeInstanceOf(Date)
            expect(updatedUser.SteamId).toBe('12345')
        })

        it('should update UpdatedAt timestamp', async () => {
            const originalUser = await getUserByEmail(postgresPool, email)

            await new Promise(resolve => setTimeout(resolve, 1000))

            const updatedUser = await updateUserByEmail(
                postgresPool,
                email,
                "Updated Name",
                "oldpassword123", 
                "12345"
            )

            expect(new Date(updatedUser.UpdatedAt).getTime())
                .toBeGreaterThanOrEqual(new Date(originalUser.UpdatedAt).getTime());

        })
    })

    describe('Category Update Operations', () => {
        let categoryId: number

        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Categories" RESTART IDENTITY CASCADE')
            await createUser(postgresPool, "John Doe", "john@doe.com", "password123", "12345")
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


    describe('Backlog Entry Update Operations', () => {
        let backlogEntryId: number

        beforeEach(async () => {
            await postgresPool.query('TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE')
            await postgresPool.query('TRUNCATE TABLE "blm-system"."BacklogEntries" RESTART IDENTITY CASCADE')

            await createUser(postgresPool, "John Doe", "john@doe.com", "password123", "12345")
            await createUser(postgresPool, "John Doe", "john@doe.com", "password123")

            await createBacklogEntry(
                postgresPool,
                1,
                "Elden Ring",
                "RPG",
                "PC",
                "Not Started",
                false,
                3,
                null,
                null,
                null,
                null,
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
                "Elden Ring",
                "RPG",
                "PC",
                "Completed",
                true,
                5,
                new Date('2024-01-15'),
                "image.jpg",
                50,
                100,
                150,
                5,
                "Amazing game!",
                "Finished after 100 hours"
            )

            expect(updatedEntry.BacklogEntryID).toBe('1')
            expect(updatedEntry.Title).toBe('Elden Ring')
            expect(updatedEntry.Genre).toBe('RPG')
            expect(updatedEntry.Platform).toBe('PC')
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
                "Elden Ring",
                "RPG",
                "PC",
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
                "Elden Ring",
                "RPG",
                "PC",
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
                "Elden Ring",
                "RPG",
                "PC",
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
                "Elden Ring",
                "RPG",
                "PC",
                "Completed",
                true,
                5,
                null,
                null,
                null,
                null,
                null,
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
                "Elden Ring",
                "RPG",
                "PC",
                "Completed",
                true,
                5,
                null,
                null,
                null,
                null,
                null,
                5,
                "Great game",
                "Some notes"
            )

            const updatedEntry = await updateBacklogEntry(
                postgresPool,
                backlogEntryId,
                "Elden Ring",
                "RPG",
                "PC",
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
                "Elden Ring",
                "RPG",
                "PC",
                "In Progress",
                false,
                4
            )

            expect(new Date(updatedEntry.UpdatedAt).getTime())
                .toBeGreaterThanOrEqual(new Date(originalEntry.UpdatedAt).getTime())
        })
    })
})
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { Pool } from 'pg'
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql'
import fs from 'fs'
import path from 'path'
import { createUser} from '../server/db/CRUD/create'
import { getAllUsers } from "~/server/db/CRUD/read";

describe('Customer Repository', () => {
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

        // SQL-Datei laden
        const sql = fs.readFileSync(path.resolve(__dirname, '../../postgres/backlogmanagerdb-init.sql'), 'utf-8')

        // SQL ausführen
        await postgresPool.query(sql)
    }, 60000)

    afterAll(async () => {
        await postgresPool.end()
        await postgresContainer.stop()
    })

    it('should create and return multiple customers', async () => {

        await createUser(postgresPool,"John Doe", "john@doe", "1234567890")
        await createUser(postgresPool,"Jane Doe", "jane@doe", "1234567890")
        const now = new Date();
        now.setHours(now.getHours() - 2);
        now.setSeconds(0, 0)

        const customers = await getAllUsers(postgresPool)
        expect(customers).toEqual([{ UserID: '1', Username: 'John Doe', Email: 'john@doe', PasswordHash: '1234567890', CreatedAt: now, UpdatedAt: now},{ UserID: '2', Username: 'Jane Doe', Email: 'jane@doe', PasswordHash: '1234567890', CreatedAt: now, UpdatedAt: now}])
    })
})



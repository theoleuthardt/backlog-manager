import type { Pool, PoolClient } from "pg";
import { handleDatabaseError } from "../types/errors";

/**
 * Execute a function within a database transaction
 * Automatically handles BEGIN, COMMIT, and ROLLBACK
 *
 * @example
 * const result = await withTransaction(pool, async (client) => {
 *   await client.query('INSERT INTO ...');
 *   await client.query('UPDATE ...');
 *   return { success: true };
 * });
 */
export async function withTransaction<T>(
  pool: Pool,
  callback: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Execute multiple queries in a transaction
 * Useful for simple multi-step operations
 *
 * @example
 * await executeInTransaction(pool, 'deleteEntry', [
 *   { query: 'DELETE FROM table1 WHERE id = $1', params: [id] },
 *   { query: 'DELETE FROM table2 WHERE id = $1', params: [id] }
 * ]);
 */
export async function executeInTransaction(
  pool: Pool,
  operation: string,
  queries: Array<{ query: string; params?: any[] }>
): Promise<void> {
  try {
    await withTransaction(pool, async (client) => {
      for (const { query, params } of queries) {
        await client.query(query, params);
      }
    });
  } catch (error) {
    handleDatabaseError(error, operation);
  }
}

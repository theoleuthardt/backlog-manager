import pool from "~/server/db";

export const createUser = async (name: string, email: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(
      "INSERT INTO Users (name, email) VALUES ($1, $2) RETURNING *",
      [name, email],
    );
    return result.rows[0];
  } catch (error) {
    console.error("Error creating user:", error);
    throw error;
  } finally {
    client.release();
  }
};

import { Pool } from "pg";

console.log("🔌 POSTGRES_URL:", process.env.POSTGRES_URL);

const pool = new Pool({
  connectionString: process.env.POSTGRES_URL,
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
  connectionTimeoutMillis: 2000, // Return an error after 2 seconds if connection could not be established
});

export default pool;

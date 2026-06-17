import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// node-postgres returns BIGINT/BIGSERIAL (OID 20) as strings by default to avoid
// JS precision loss. Our IDs/XP are within safe integer range, so parse as numbers.
pg.types.setTypeParser(20, (val) => parseInt(val, 10));

// Set DB_SSL=require (or true) on the backend if your Postgres needs SSL.
// Leave it unset for a server that does not use SSL (default).
const useSsl = ['require', 'true', '1'].includes((process.env.DB_SSL || '').toLowerCase());

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  options: '-c search_path=fitquest',
  ssl: useSsl ? { rejectUnauthorized: false } : false,
});

export const q = (text, params) => pool.query(text, params);

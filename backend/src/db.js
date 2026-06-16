import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// node-postgres returns BIGINT/BIGSERIAL (OID 20) as strings by default to avoid
// JS precision loss on very large numbers. Our IDs and XP values are well within
// safe integer range, so parse them as numbers everywhere.
pg.types.setTypeParser(20, (val) => parseInt(val, 10));

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  options: '-c search_path=fitquest',
});

export const q = (text, params) => pool.query(text, params);

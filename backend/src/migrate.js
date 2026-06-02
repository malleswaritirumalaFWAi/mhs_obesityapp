import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { pool } from './db.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function run() {
  const schema = readFileSync(join(__dirname, 'schema.sql'), 'utf8');
  const seed = readFileSync(join(__dirname, 'seed.sql'), 'utf8');
  const client = await pool.connect();
  try {
    console.log('Applying schema…');
    await client.query(schema);
    console.log('Seeding reference data…');
    await client.query(seed);
    console.log('✅ Migration complete.');
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch((e) => {
  console.error('❌ Migration failed:', e.message);
  process.exit(1);
});

// Additive migration for the achievements feature (Steam-style unlocks).
// Idempotent.
// Run with: npx tsx scripts/migrate-2026-07-batch5.ts
import 'dotenv/config';
import { Pool } from 'pg';

const connectionString =
  process.env.DATABASE_URL || 'postgres://life_achiever:password@localhost:5432/life_achiever';

const pool = new Pool({
  connectionString,
  ssl: connectionString.includes('localhost') ? undefined : { rejectUnauthorized: false },
  max: 1,
});

const statements = [
  `CREATE TABLE IF NOT EXISTS user_achievements (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key text NOT NULL,
    unlocked_at timestamp NOT NULL DEFAULT now()
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS user_achievements_user_key_idx ON user_achievements(user_id, key)`,
];

async function main() {
  for (const sql of statements) {
    await pool.query(sql);
    console.log('ok:', sql.replace(/\s+/g, ' ').slice(0, 80));
  }
  await pool.end();
  console.log('migration complete');
}

main().catch((err) => {
  console.error('migration failed:', err.message);
  process.exit(1);
});

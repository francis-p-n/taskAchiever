// Additive migration for cross-device player profile sync. Idempotent.
// Run with: npx tsx scripts/migrate-2026-07-batch3.ts
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
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS player_profile text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS player_profile_updated_at timestamp`,
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

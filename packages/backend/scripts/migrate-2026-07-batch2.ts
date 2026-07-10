// Additive migration for the July 2026 batch 2 (archive, push notifications,
// reminders). Idempotent: safe to re-run.
// Run with: npx tsx scripts/migrate-2026-07-batch2.ts
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
  `ALTER TABLE quests ADD COLUMN IF NOT EXISTS archived_at timestamp`,
  `ALTER TABLE quests ADD COLUMN IF NOT EXISTS reminder_sent_at timestamp`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS reminders_enabled boolean DEFAULT true`,
  `CREATE TABLE IF NOT EXISTS device_tokens (
     id serial PRIMARY KEY,
     user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     token text NOT NULL,
     platform text,
     created_at timestamp NOT NULL DEFAULT now(),
     last_seen_at timestamp NOT NULL DEFAULT now()
   )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS device_tokens_token_idx ON device_tokens (token)`,
  `CREATE INDEX IF NOT EXISTS device_tokens_user_idx ON device_tokens (user_id)`,
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

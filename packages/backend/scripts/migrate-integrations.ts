// One-off additive migration for the integrations work (2026-07).
// Idempotent: safe to re-run. Run with: npx tsx scripts/migrate-integrations.ts
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
  `ALTER TABLE quests ADD COLUMN IF NOT EXISTS todoist_synced_at timestamp`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS todoist_last_sync_at timestamp`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS ical_url text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS calendar_last_sync_at timestamp`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS plaid_access_token text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS plaid_item_id text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS plaid_cursor text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS plaid_last_sync_at timestamp`,
  `ALTER TABLE transactions ADD COLUMN IF NOT EXISTS external_id text`,
  `CREATE UNIQUE INDEX IF NOT EXISTS transactions_user_external_idx
     ON transactions (user_id, external_id)`,
  `ALTER TABLE schedule_events ADD COLUMN IF NOT EXISTS external_id text`,
  `CREATE UNIQUE INDEX IF NOT EXISTS schedule_events_user_external_idx
     ON schedule_events (user_id, external_id)`,
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

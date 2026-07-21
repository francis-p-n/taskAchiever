// Additive migration for quest-centric tracking (lifeOS v2, quest-first):
// quest links on the tracking tables + the tag bonus XP column on quests.
// Idempotent.
// Run with: npx tsx scripts/migrate-2026-07-quest-tracking.ts
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
  `ALTER TABLE quests ADD COLUMN IF NOT EXISTS tracking_bonus_xp integer DEFAULT 0`,
  `ALTER TABLE time_entries ADD COLUMN IF NOT EXISTS quest_id text`,
  `CREATE INDEX IF NOT EXISTS time_entries_quest_idx ON time_entries(quest_id)`,
  `ALTER TABLE transactions ADD COLUMN IF NOT EXISTS quest_id text`,
  `CREATE INDEX IF NOT EXISTS transactions_quest_idx ON transactions(quest_id)`,
  `ALTER TABLE contact_interactions ADD COLUMN IF NOT EXISTS quest_id text`,
  `CREATE INDEX IF NOT EXISTS contact_interactions_quest_idx ON contact_interactions(quest_id)`,
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

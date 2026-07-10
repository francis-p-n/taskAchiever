// Additive migration for the July 2026 feature batch (recurring quests,
// Strava, health sync). Idempotent: safe to re-run.
// Run with: npx tsx scripts/migrate-2026-07-features.ts
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
  `ALTER TABLE quests ADD COLUMN IF NOT EXISTS recurrence text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS strava_athlete_id text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS strava_access_token text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS strava_refresh_token text`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS strava_expires_at timestamp`,
  `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS strava_last_sync_at timestamp`,
  `CREATE TABLE IF NOT EXISTS activities (
     id serial PRIMARY KEY,
     user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     source text NOT NULL,
     external_id text,
     name text NOT NULL,
     sport_type text,
     start_time timestamp NOT NULL,
     duration_seconds integer DEFAULT 0,
     distance_meters integer,
     calories_burned integer DEFAULT 0,
     avg_heart_rate integer,
     created_at timestamp NOT NULL DEFAULT now()
   )`,
  `CREATE INDEX IF NOT EXISTS activities_user_start_idx ON activities (user_id, start_time)`,
  `CREATE UNIQUE INDEX IF NOT EXISTS activities_user_external_idx
     ON activities (user_id, source, external_id)`,
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

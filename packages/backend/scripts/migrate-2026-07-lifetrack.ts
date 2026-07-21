// Additive migration for the lifeOS v2 life-tracking domains: time entries,
// daily wellness check-ins, contacts + interactions, habits + completions.
// Idempotent.
// Run with: npx tsx scripts/migrate-2026-07-lifetrack.ts
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
  `CREATE TABLE IF NOT EXISTS time_entries (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category text NOT NULL,
    start_time timestamp NOT NULL,
    duration_minutes integer NOT NULL,
    notes text,
    mood_before integer,
    energy_before integer,
    mood_after integer,
    energy_after integer,
    roi_score integer,
    created_at timestamp NOT NULL DEFAULT now(),
    updated_at timestamp NOT NULL DEFAULT now()
  )`,
  `CREATE INDEX IF NOT EXISTS time_entries_user_start_idx ON time_entries(user_id, start_time)`,

  `CREATE TABLE IF NOT EXISTS daily_checkins (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date timestamp NOT NULL,
    morning_mood integer,
    morning_energy integer,
    morning_stress integer,
    sleep_minutes integer,
    evening_mood integer,
    evening_energy integer,
    evening_stress integer,
    created_at timestamp NOT NULL DEFAULT now(),
    updated_at timestamp NOT NULL DEFAULT now()
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS daily_checkins_user_date_idx ON daily_checkins(user_id, date)`,

  `CREATE TABLE IF NOT EXISTS contacts (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name text NOT NULL,
    relationship_type text DEFAULT 'friend',
    birthdate timestamp,
    email text,
    phone text,
    tags text,
    notes text,
    last_contacted_at timestamp,
    created_at timestamp NOT NULL DEFAULT now(),
    updated_at timestamp NOT NULL DEFAULT now()
  )`,
  `CREATE INDEX IF NOT EXISTS contacts_user_idx ON contacts(user_id)`,

  `CREATE TABLE IF NOT EXISTS contact_interactions (
    id serial PRIMARY KEY,
    contact_id integer NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    interaction_type text NOT NULL,
    occurred_at timestamp NOT NULL,
    notes text,
    depth_score integer,
    created_at timestamp NOT NULL DEFAULT now()
  )`,
  `CREATE INDEX IF NOT EXISTS contact_interactions_contact_idx ON contact_interactions(contact_id, occurred_at)`,

  `CREATE TABLE IF NOT EXISTS habits (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text DEFAULT 'fitness',
    difficulty integer DEFAULT 3,
    target_frequency text DEFAULT 'daily',
    current_streak_days integer DEFAULT 0,
    longest_streak_days integer DEFAULT 0,
    last_completed_at timestamp,
    freezes_remaining integer DEFAULT 2,
    active boolean DEFAULT true,
    created_at timestamp NOT NULL DEFAULT now(),
    updated_at timestamp NOT NULL DEFAULT now()
  )`,
  `CREATE INDEX IF NOT EXISTS habits_user_idx ON habits(user_id)`,

  `CREATE TABLE IF NOT EXISTS habit_completions (
    id serial PRIMARY KEY,
    habit_id integer NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    completed_at timestamp NOT NULL,
    notes text,
    streak_day integer,
    created_at timestamp NOT NULL DEFAULT now()
  )`,
  `CREATE INDEX IF NOT EXISTS habit_completions_habit_idx ON habit_completions(habit_id, completed_at)`,
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

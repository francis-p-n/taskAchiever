// Additive migration for the Body Energy metric (sleep + HRV from Health
// Connect). Idempotent.
// Run with: npx tsx scripts/migrate-2026-07-batch4.ts
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
  `ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS sleep_minutes integer`,
  `ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS hrv_rmssd integer`,
  `ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS resting_heart_rate integer`,
  `ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS spo2 integer`,
  `ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS distance_meters integer`,
  `ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS sleep_deep_minutes integer`,
  `ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS sleep_rem_minutes integer`,
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

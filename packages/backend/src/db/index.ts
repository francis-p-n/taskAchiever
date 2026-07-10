import 'dotenv/config';
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';

const connectionString =
  process.env.DATABASE_URL || 'postgres://life_achiever:password@localhost:5432/life_achiever';

// Neon (and most hosted Postgres) requires TLS; local docker does not.
const pool = new Pool({
  connectionString,
  ssl: connectionString.includes('localhost') ? undefined : { rejectUnauthorized: false },
  max: 5,
});

// An idle pooled connection dropped server-side (Neon suspends computes)
// emits 'error' on the pool; without a handler that crashes the process.
pool.on('error', (err) => {
  console.error('[pg] idle client error:', err.message);
});

export const db = drizzle(pool, { schema });

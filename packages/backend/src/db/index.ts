import { drizzle } from 'drizzle-orm/node-postgres';
import { Client } from 'pg';
import * as schema from './schema';

const client = new Client({
  connectionString: process.env.DATABASE_URL || 'postgres://life_achiever:password@localhost:5432/life_achiever',
});

client.connect().catch(console.error);

export const db = drizzle(client, { schema });

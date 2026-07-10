import Redis from 'ioredis';

// Redis is an optional accelerator (cache, session store, sync locks).
// The app must keep working against Postgres alone when it is not running,
// so every operation degrades to a no-op instead of throwing.
const client = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  lazyConnect: true,
  maxRetriesPerRequest: 0,
  retryStrategy: () => null,
});

let available = false;
client.on('error', () => {});

/** Raw client for libraries that take an ioredis instance (rate limiting).
 *  Callers must tolerate command failures when Redis is down. */
export const redisClient = client;
export const redisAvailable = () => available;
client
  .connect()
  .then(() => {
    available = true;
  })
  .catch(() => {
    console.warn('[redis] not reachable — running without cache/sessions');
  });

export const cache = {
  async get(key: string): Promise<string | null> {
    if (!available) return null;
    try {
      return await client.get(key);
    } catch {
      return null;
    }
  },

  async setEx(key: string, value: string, ttlSeconds: number): Promise<void> {
    if (!available) return;
    try {
      await client.set(key, value, 'EX', ttlSeconds);
    } catch {}
  },

  /** Returns true when the lock was acquired (always true when Redis is down — single-node fallback). */
  async setNx(key: string, value: string, ttlSeconds: number): Promise<boolean> {
    if (!available) return true;
    try {
      return (await client.set(key, value, 'EX', ttlSeconds, 'NX')) === 'OK';
    } catch {
      return true;
    }
  },

  async del(key: string): Promise<void> {
    if (!available) return;
    try {
      await client.del(key);
    } catch {}
  },
};

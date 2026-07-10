import { FastifyInstance } from 'fastify';
import { eq } from 'drizzle-orm';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { deviceTokens } from '../db/schema';
import { pushConfigured, sendToUser } from '../lib/push';

const tokenBody = {
  type: 'object',
  properties: {
    token: { type: 'string', minLength: 1, maxLength: 4096 },
    platform: { type: 'string', enum: ['android', 'ios', 'web'] },
  },
  required: ['token'],
} as const;

export default async function notificationRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // Register (or refresh) this install's FCM token. A token moving between
  // accounts on the same device re-homes to the newest login.
  fastify.post('/api/notifications/register', { schema: { body: tokenBody } }, async (request, reply) => {
    const user = request.user as { id: number };
    const { token, platform } = request.body as { token: string; platform?: string };

    await db.insert(deviceTokens)
      .values({ userId: user.id, token, platform })
      .onConflictDoUpdate({
        target: deviceTokens.token,
        set: { userId: user.id, platform, lastSeenAt: new Date() },
      });

    return reply.send({ registered: true, pushConfigured: pushConfigured() });
  });

  fastify.delete('/api/notifications/register', { schema: { body: tokenBody } }, async (request, reply) => {
    const { token } = request.body as { token: string };
    await db.delete(deviceTokens).where(eq(deviceTokens.token, token));
    return reply.send({ unregistered: true });
  });

  // Fire a real push at yourself to confirm the whole chain works.
  fastify.post('/api/notifications/test', {
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const sent = await sendToUser(user.id, 'lifeOS', 'Push notifications are working.');
    return reply.send({ sent, pushConfigured: pushConfigured() });
  });
}

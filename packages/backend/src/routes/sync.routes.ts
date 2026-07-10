import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { quests, questSteps } from '../db/schema';
import { eq, gt } from 'drizzle-orm';
import { cache } from '../lib/redis';

export default async function syncRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // Client pulls updates from the server that occurred after a specific timestamp
  fastify.get('/api/sync/pull', async (request, reply) => {
    const user = request.user as { id: number };
    const { since } = request.query as { since?: string };
    
    let lastSync = since ? new Date(since) : new Date(0);

    // Fetch entities modified after `lastSync`
    const updatedQuests = await db.query.quests.findMany({
      where: (quests, { and, eq, gt }) => and(eq(quests.userId, user.id), gt(quests.updatedAt, lastSync)),
      with: { steps: true }
    });

    return reply.send({
      timestamp: new Date().toISOString(),
      quests: updatedQuests,
      // fitness, food, spending entities would go here
    });
  });

  // Client pushes an offline queue of operations to the server
  fastify.post('/api/sync/push', {
    schema: {
      body: {
        type: 'object',
        properties: {
          operations: {
            type: 'array',
            maxItems: 500,
            items: {
              type: 'object',
              properties: {
                collection: { type: 'string', maxLength: 50 },
                action: { type: 'string', maxLength: 50 },
                data: { type: 'object' },
              },
              required: ['collection', 'action', 'data'],
            },
          },
        },
        required: ['operations'],
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { operations } = request.body as { operations: any[] };

    // Prevent concurrent syncs for the same user domain using Redis Lock
    const lockKey = `sync:lock:${user.id}:quests`;
    const lock = await cache.setNx(lockKey, 'locked', 30);
    
    if (!lock) {
      return reply.status(409).send({ error: 'Sync already in progress' });
    }

    try {
      const results = [];
      for (const op of operations) {
        if (op.collection === 'quests') {
          if (op.action === 'upsert') {
            const [quest] = await db.insert(quests).values({
              id: op.data.id,
              userId: user.id,
              title: op.data.title,
              description: op.data.description,
              difficulty: op.data.difficulty,
            })
            .onConflictDoUpdate({
              target: quests.id,
              set: {
                title: op.data.title,
                description: op.data.description,
                difficulty: op.data.difficulty,
                updatedAt: new Date()
              }
            }).returning();
            results.push({ id: op.data.id, status: 'success' });
          }
        }
      }

      await cache.del(`quests:${user.id}`);
      return reply.send({ success: true, timestamp: new Date().toISOString(), results });
    } finally {
      await cache.del(lockKey);
    }
  });
}

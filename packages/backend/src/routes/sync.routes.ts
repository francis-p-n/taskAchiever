import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { quests, questSteps } from '../db/schema';
import { eq, gt, and } from 'drizzle-orm';
import { cache } from '../lib/redis';
import { QuestService } from '../services/quest.service';

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
        if (op.collection !== 'quests') {
          results.push({ id: op.data?.id, status: 'unsupported' });
          continue;
        }
        // `at` is when the client performed the action offline — the basis
        // for last-write-wins against the server row's updatedAt.
        const opAt = op.data?.at ? new Date(op.data.at) : null;

        if (op.action === 'upsert') {
          const existing = await db.query.quests.findFirst({
            where: and(eq(quests.id, op.data.id), eq(quests.userId, user.id)),
          });
          if (existing && opAt && existing.updatedAt > opAt) {
            // Server changed after the offline edit: server wins, client
            // reconciles from the returned row.
            results.push({ id: op.data.id, status: 'conflict', server: existing });
            continue;
          }
          await db.insert(quests).values({
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
          });
          results.push({ id: op.data.id, status: 'applied' });
        } else if (op.action === 'complete' || op.action === 'uncomplete') {
          // Completion replay goes through the service so XP, streaks and
          // recurrence behave exactly like an online completion. Both are
          // idempotent, so replaying an op the server already saw is safe.
          try {
            const quest = op.action === 'complete'
              ? await QuestService.completeQuest(user.id, op.data.id, op.data.fulfillment ?? 3)
              : await QuestService.uncompleteQuest(user.id, op.data.id);
            results.push({ id: op.data.id, status: 'applied', server: quest });
          } catch {
            // Quest deleted while offline — drop the op, nothing to conflict with.
            results.push({ id: op.data.id, status: 'missing' });
          }
        } else {
          results.push({ id: op.data?.id, status: 'unsupported' });
        }
      }

      await QuestService.bustQuestCache(user.id);
      return reply.send({ success: true, timestamp: new Date().toISOString(), results });
    } finally {
      await cache.del(lockKey);
    }
  });
}

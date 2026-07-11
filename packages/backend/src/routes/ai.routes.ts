import { FastifyInstance } from 'fastify';
import { desc, eq } from 'drizzle-orm';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { quests } from '../db/schema';
import { generateSteps, suggestQuests } from '../services/ai.service';

export { aiConfigured } from '../services/ai.service';

export default async function aiRoutes(fastify: FastifyInstance) {
  fastify.post('/api/ai/generate-roadmap', { preHandler: authenticate }, async (request, reply) => {
    const { title } = request.body as { title?: string };
    if (!title || !title.trim()) {
      return reply.status(400).send({ error: 'title is required' });
    }

    // Local-first app: generateSteps never throws, it degrades to a
    // heuristic breakdown so quest creation always works.
    const result = await generateSteps(title);
    return reply.send(result);
  });

  // Side-quest ideas grounded in what the player has actually been doing;
  // `focus` optionally names their least-developed life area so the ideas
  // pull the radar back into balance.
  fastify.post('/api/ai/suggest-quests', {
    preHandler: authenticate,
    config: { rateLimit: { max: 20, timeWindow: '1 hour' } },
    schema: {
      body: {
        type: 'object',
        properties: { focus: { type: 'string', maxLength: 40 } },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { focus } = (request.body ?? {}) as { focus?: string };

    const recent = await db.query.quests.findMany({
      where: eq(quests.userId, user.id),
      orderBy: [desc(quests.updatedAt)],
      limit: 20,
      columns: { title: true },
    });

    const result = await suggestQuests(recent.map((q) => q.title), focus);
    return reply.send(result);
  });
}

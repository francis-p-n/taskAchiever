import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { generateSteps } from '../services/ai.service';

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
}

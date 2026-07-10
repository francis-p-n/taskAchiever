import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { SummaryService } from '../services/summary.service';

export default async function summaryRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/summary/weekly', {
    schema: {
      querystring: {
        type: 'object',
        properties: { offset: { type: 'integer', minimum: 0, maximum: 52, default: 0 } },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { offset } = request.query as { offset: number };
    return reply.send(await SummaryService.weekly(user.id, offset ?? 0));
  });

  fastify.get('/api/summary/trends', {
    schema: {
      querystring: {
        type: 'object',
        properties: { weeks: { type: 'integer', minimum: 2, maximum: 26, default: 8 } },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { weeks } = request.query as { weeks: number };
    return reply.send(await SummaryService.trends(user.id, weeks ?? 8));
  });
}

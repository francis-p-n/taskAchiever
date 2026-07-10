import { FastifyInstance } from 'fastify';
import { QuestService } from '../services/quest.service';
import { authenticate } from '../middleware/auth';

export default async function questRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/quests', async (request, reply) => {
    const user = request.user as { id: number };
    const quests = await QuestService.getQuests(user.id);
    return reply.send(quests);
  });

  fastify.post('/api/quests', async (request, reply) => {
    const user = request.user as { id: number };
    const quest = await QuestService.createQuest(user.id, request.body);
    return reply.status(201).send(quest);
  });

  fastify.get('/api/stats', async (request, reply) => {
    const user = request.user as { id: number };
    const stats = await QuestService.getStats(user.id);
    return reply.send(stats || {});
  });

  fastify.post('/api/quests/:id/complete', async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    const { fulfillment } = request.body as { fulfillment: number };
    
    try {
      const completed = await QuestService.completeQuest(user.id, id, fulfillment);
      return reply.send(completed);
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });
}

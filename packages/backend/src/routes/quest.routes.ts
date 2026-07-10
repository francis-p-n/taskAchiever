import { FastifyInstance } from 'fastify';
import { QuestService } from '../services/quest.service';
import { authenticate } from '../middleware/auth';

const idParams = {
  type: 'object',
  properties: { id: { type: 'string', minLength: 1, maxLength: 128 } },
  required: ['id'],
} as const;

const questBody = {
  type: 'object',
  properties: {
    id: { type: 'string', maxLength: 128 },
    title: { type: 'string', minLength: 1, maxLength: 300 },
    description: { type: ['string', 'null'], maxLength: 5000 },
    category: { type: ['string', 'null'], maxLength: 100 },
    difficulty: { type: ['integer', 'null'], minimum: 1, maximum: 5 },
    dueDate: { type: ['string', 'null'] },
    recurrence: { type: ['string', 'null'], enum: ['daily', 'weekly', null] },
    todoistId: { type: ['string', 'null'] },
    steps: {
      type: 'array',
      maxItems: 50,
      items: {
        type: 'object',
        properties: {
          id: { type: 'string', maxLength: 128 },
          text: { type: 'string', minLength: 1, maxLength: 500 },
        },
        required: ['text'],
      },
    },
  },
  required: ['title'],
} as const;

export default async function questRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/quests', async (request, reply) => {
    const user = request.user as { id: number };
    const { includeArchived } = request.query as { includeArchived?: string };
    const quests = await QuestService.getQuests(user.id, includeArchived === 'true');
    return reply.send(quests);
  });

  fastify.post('/api/quests/:id/archive', { schema: { params: idParams } }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    try {
      return reply.send(await QuestService.archiveQuest(user.id, id, true));
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });

  fastify.post('/api/quests/:id/unarchive', { schema: { params: idParams } }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    try {
      return reply.send(await QuestService.archiveQuest(user.id, id, false));
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });

  fastify.delete('/api/quests/:id', { schema: { params: idParams } }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    try {
      return reply.send(await QuestService.deleteQuest(user.id, id));
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });

  fastify.post('/api/quests', { schema: { body: questBody } }, async (request, reply) => {
    const user = request.user as { id: number };
    const quest = await QuestService.createQuest(user.id, request.body);
    return reply.status(201).send(quest);
  });

  fastify.get('/api/stats', async (request, reply) => {
    const user = request.user as { id: number };
    const stats = await QuestService.getStats(user.id);
    return reply.send(stats || {});
  });

  fastify.post('/api/quests/:id/complete', {
    schema: {
      params: idParams,
      body: {
        type: 'object',
        properties: { fulfillment: { type: ['integer', 'null'], minimum: 0, maximum: 5 } },
      },
    },
  }, async (request, reply) => {
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

  fastify.post('/api/quests/:id/uncomplete', { schema: { params: idParams } }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };

    try {
      const quest = await QuestService.uncompleteQuest(user.id, id);
      return reply.send(quest);
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });
}

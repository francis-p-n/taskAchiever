import { FastifyInstance } from 'fastify';
import { QuestService } from '../services/quest.service';
import { AchievementService } from '../services/achievements.service';
import { TrackingService, QuestTrackingInput } from '../services/tracking.service';
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

  fastify.patch('/api/quests/:id', {
    schema: {
      params: idParams,
      body: {
        type: 'object',
        properties: {
          title: { type: 'string', minLength: 1, maxLength: 300 },
          description: { type: ['string', 'null'], maxLength: 5000 },
          category: { type: ['string', 'null'], maxLength: 100 },
          difficulty: { type: 'integer', minimum: 1, maximum: 5 },
          dueDate: { type: ['string', 'null'] },
          recurrence: { type: ['string', 'null'], enum: ['daily', 'weekly', null] },
        },
        additionalProperties: false,
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    try {
      return reply.send(await QuestService.updateQuest(user.id, id, request.body));
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });

  // AI action-step breakdown, triggered from the quest's "generate steps"
  // button. Kept off the global limit: one Claude call per press.
  fastify.post('/api/quests/:id/generate-steps', {
    config: { rateLimit: { max: 30, timeWindow: '1 hour' } },
    schema: { params: idParams },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    try {
      return reply.send(await QuestService.generateStepsForQuest(user.id, id));
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

  const scale = { type: 'integer', minimum: 1, maximum: 10 };
  fastify.post('/api/quests/:id/complete', {
    schema: {
      params: idParams,
      body: {
        type: 'object',
        properties: {
          fulfillment: { type: ['integer', 'null'], minimum: 0, maximum: 5 },
          // Optional opt-in tracking metadata — each tagged domain earns
          // +5 bonus XP; skipping everything is a plain completion.
          tracking: {
            type: 'object',
            properties: {
              durationMinutes: { type: 'integer', minimum: 1, maximum: 24 * 60 },
              timeCategory: { type: 'string', maxLength: 20 },
              moodBefore: scale,
              moodAfter: scale,
              energyBefore: scale,
              energyAfter: scale,
              spendingCents: { type: 'integer', minimum: 1 },
              spendingCategory: { type: 'string', maxLength: 50 },
              spendingMerchant: { type: 'string', maxLength: 255 },
              contactId: { type: 'integer', minimum: 1 },
              interactionType: {
                type: 'string',
                enum: ['text', 'call', 'meet', 'gift', 'shared-memory'],
              },
            },
          },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    const { fulfillment, tracking } = request.body as {
      fulfillment: number;
      tracking?: QuestTrackingInput;
    };

    try {
      // Idempotence guard: a re-completion must not re-apply tracking.
      const before = await QuestService.getQuestById(user.id, id);
      const wasCompleted = Boolean(before?.completedAt);

      const completed = await QuestService.completeQuest(user.id, id, fulfillment);

      let bonusXp = 0;
      let tagged: string[] = [];
      if (tracking && !wasCompleted && before) {
        const result = await TrackingService.applyQuestTracking(
          user.id, id, before.title, tracking
        );
        bonusXp = result.bonusXp;
        tagged = result.tagged;
      }

      const newlyUnlocked = await AchievementService.evaluate(user.id);
      return reply.send({ ...completed, trackingBonusXp: bonusXp, tagged, newlyUnlocked });
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });

  // Late tagging: the client completes first (snappy UX), then the optional
  // tracking sheet posts here. One shot per completion — a quest that already
  // carries a tag bonus (or is not completed) is rejected.
  fastify.post('/api/quests/:id/tracking', {
    schema: {
      params: idParams,
      body: {
        type: 'object',
        properties: {
          durationMinutes: { type: 'integer', minimum: 1, maximum: 24 * 60 },
          timeCategory: { type: 'string', maxLength: 20 },
          moodBefore: scale,
          moodAfter: scale,
          energyBefore: scale,
          energyAfter: scale,
          spendingCents: { type: 'integer', minimum: 1 },
          spendingCategory: { type: 'string', maxLength: 50 },
          spendingMerchant: { type: 'string', maxLength: 255 },
          contactId: { type: 'integer', minimum: 1 },
          interactionType: {
            type: 'string',
            enum: ['text', 'call', 'meet', 'gift', 'shared-memory'],
          },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };
    const tracking = request.body as QuestTrackingInput;

    const quest = await QuestService.getQuestById(user.id, id);
    if (!quest) {
      return reply.status(404).send({ error: 'Quest not found' });
    }
    if (!quest.completedAt) {
      return reply.status(409).send({
        error: 'NOT_COMPLETED',
        message: 'Tracking tags attach to completed quests only',
        statusCode: 409,
      });
    }
    if ((quest.trackingBonusXp ?? 0) > 0) {
      return reply.status(409).send({
        error: 'ALREADY_TAGGED',
        message: 'This completion already has tracking tags',
        statusCode: 409,
      });
    }

    const result = await TrackingService.applyQuestTracking(
      user.id, id, quest.title, tracking
    );
    return reply.status(201).send(result);
  });

  fastify.post('/api/quests/:id/uncomplete', { schema: { params: idParams } }, async (request, reply) => {
    const user = request.user as { id: number };
    const { id } = request.params as { id: string };

    try {
      const quest = await QuestService.uncompleteQuest(user.id, id);
      // Undo is symmetric: tagged tracking rows and their bonus XP go too.
      await TrackingService.revertQuestTracking(user.id, id);
      return reply.send(quest);
    } catch (err: any) {
      return reply.status(404).send({ error: err.message });
    }
  });
}

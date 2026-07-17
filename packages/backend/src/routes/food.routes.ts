import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { nutritionLogs } from '../db/schema';
import { eq, and, gte } from 'drizzle-orm';
import { aiConfigured, analyzeMealPhoto } from '../services/ai.service';
import { AchievementService } from '../services/achievements.service';

const IMAGE_MEDIA_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
const MAX_IMAGE_BASE64_CHARS = 7_000_000; // ~5 MB binary, the vision API limit

export default async function foodRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/food/today', async (request, reply) => {
    const user = request.user as { id: number };
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const logs = await db.query.nutritionLogs.findMany({
      where: and(
        eq(nutritionLogs.userId, user.id),
        gte(nutritionLogs.loggedAt, today)
      )
    });

    return reply.send(logs);
  });

  fastify.post('/api/food', async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as any;

    const [log] = await db.insert(nutritionLogs).values({
      userId: user.id,
      mealType: data.mealType,
      calories: data.calories,
      protein: data.protein,
      carbs: data.carbs,
      fats: data.fats,
      loggedAt: new Date(),
    }).returning();

    const newlyUnlocked = await AchievementService.evaluate(user.id);
    return reply.status(201).send({ ...log, newlyUnlocked });
  });

  // Photo → estimated calories + macros (Claude vision). The client shows
  // the estimate in the log-meal form for the user to confirm.
  fastify.post('/api/food/analyze', {
    bodyLimit: 12_000_000, // allow phone photos; default 1 MB is too small
  }, async (request, reply) => {
    if (!aiConfigured()) {
      return reply.status(503).send({ error: 'AI not configured on the server' });
    }

    const { image, mediaType } = request.body as { image?: string; mediaType?: string };
    if (!image) return reply.status(400).send({ error: 'image (base64) is required' });
    if (!mediaType || !IMAGE_MEDIA_TYPES.has(mediaType)) {
      return reply.status(400).send({ error: 'mediaType must be image/jpeg, png, webp or gif' });
    }
    if (image.length > MAX_IMAGE_BASE64_CHARS) {
      return reply.status(413).send({ error: 'Image too large — keep it under ~5 MB' });
    }

    const estimate = await analyzeMealPhoto(image, mediaType as any);
    if (!estimate) {
      return reply.status(502).send({ error: 'Could not analyze the photo' });
    }
    return reply.send(estimate);
  });
}

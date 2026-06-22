import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { nutritionLogs } from '../db/schema';
import { eq, and, gte } from 'drizzle-orm';

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

    return reply.status(201).send(log);
  });
}

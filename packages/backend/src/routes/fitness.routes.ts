import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { healthMetrics } from '../db/schema';
import { eq, and, gte } from 'drizzle-orm';

export default async function fitnessRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/fitness/daily', async (request, reply) => {
    const user = request.user as { id: number };
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const metrics = await db.query.healthMetrics.findFirst({
      where: and(
        eq(healthMetrics.userId, user.id),
        gte(healthMetrics.date, today)
      )
    });

    return reply.send(metrics || {});
  });

  fastify.post('/api/fitness', async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as any;

    const [metric] = await db.insert(healthMetrics).values({
      userId: user.id,
      date: new Date(),
      steps: data.steps,
      caloriesBurned: data.caloriesBurned,
      heartRateMin: data.heartRateMin,
      heartRateMax: data.heartRateMax,
      sleepScore: data.sleepScore,
    }).returning();

    return reply.status(201).send(metric);
  });
}

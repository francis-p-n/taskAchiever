import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { scheduleEvents } from '../db/schema';
import { eq, and, gte, lte } from 'drizzle-orm';

export default async function scheduleRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/schedule/today', async (request, reply) => {
    const user = request.user as { id: number };
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const events = await db.query.scheduleEvents.findMany({
      where: and(
        eq(scheduleEvents.userId, user.id),
        gte(scheduleEvents.startTime, today),
        lte(scheduleEvents.startTime, endOfDay)
      )
    });

    return reply.send(events);
  });

  fastify.post('/api/schedule', async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as any;

    const [event] = await db.insert(scheduleEvents).values({
      userId: user.id,
      title: data.title,
      startTime: new Date(data.startTime),
      endTime: new Date(data.endTime),
      isGoogleEvent: data.isGoogleEvent || false,
    }).returning();

    return reply.status(201).send(event);
  });
}

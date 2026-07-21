import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { dailyCheckins } from '../db/schema';
import { eq, desc, and, gte, sql } from 'drizzle-orm';

/** Midnight UTC for a YYYY-MM-DD string (client sends its local day). */
function parseDay(raw?: string): Date | null {
  const day = raw ?? new Date().toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return null;
  const date = new Date(`${day}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

const scale = { type: 'integer', minimum: 1, maximum: 10 };

export default async function checkinRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // Upsert the day's check-in: morning and evening arrive as separate calls,
  // each only touching its own fields.
  fastify.post('/api/checkins', {
    schema: {
      body: {
        type: 'object',
        properties: {
          date: { type: 'string' }, // YYYY-MM-DD; defaults to today (UTC)
          morningMood: scale,
          morningEnergy: scale,
          morningStress: scale,
          sleepMinutes: { type: 'integer', minimum: 0, maximum: 24 * 60 },
          eveningMood: scale,
          eveningEnergy: scale,
          eveningStress: scale,
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as {
      date?: string;
      morningMood?: number;
      morningEnergy?: number;
      morningStress?: number;
      sleepMinutes?: number;
      eveningMood?: number;
      eveningEnergy?: number;
      eveningStress?: number;
    };

    const date = parseDay(data.date);
    if (!date) {
      return reply.status(400).send({
        error: 'BAD_DATE',
        message: 'date must be YYYY-MM-DD',
        statusCode: 400,
      });
    }

    const fields = {
      morningMood: data.morningMood,
      morningEnergy: data.morningEnergy,
      morningStress: data.morningStress,
      sleepMinutes: data.sleepMinutes,
      eveningMood: data.eveningMood,
      eveningEnergy: data.eveningEnergy,
      eveningStress: data.eveningStress,
    };
    // Only overwrite columns the client actually sent, so an evening call
    // never blanks the morning numbers.
    const provided = Object.fromEntries(
      Object.entries(fields).filter(([, v]) => v !== undefined)
    );

    const [row] = await db.insert(dailyCheckins)
      .values({ userId: user.id, date, ...provided })
      .onConflictDoUpdate({
        target: [dailyCheckins.userId, dailyCheckins.date],
        set: { ...provided, updatedAt: new Date() },
      })
      .returning();

    return reply.status(201).send(row);
  });

  // Trailing window of check-ins plus averages for the trend line.
  fastify.get('/api/checkins/recent', async (request, reply) => {
    const user = request.user as { id: number };
    const days = Math.min(Number((request.query as { days?: string }).days) || 14, 90);
    const since = new Date(Date.now() - days * 24 * 3600 * 1000);

    const rows = await db.query.dailyCheckins.findMany({
      where: and(eq(dailyCheckins.userId, user.id), gte(dailyCheckins.date, since)),
      orderBy: [desc(dailyCheckins.date)],
    });

    const [avgs] = await db
      .select({
        mood: sql<string>`round(avg(coalesce(${dailyCheckins.eveningMood}, ${dailyCheckins.morningMood})), 1)`,
        energy: sql<string>`round(avg(coalesce(${dailyCheckins.eveningEnergy}, ${dailyCheckins.morningEnergy})), 1)`,
        sleepMinutes: sql<string>`round(avg(${dailyCheckins.sleepMinutes}))`,
      })
      .from(dailyCheckins)
      .where(and(eq(dailyCheckins.userId, user.id), gte(dailyCheckins.date, since)));

    return reply.send({
      days,
      checkins: rows,
      averages: {
        mood: avgs?.mood != null ? Number(avgs.mood) : null,
        energy: avgs?.energy != null ? Number(avgs.energy) : null,
        sleepMinutes: avgs?.sleepMinutes != null ? Number(avgs.sleepMinutes) : null,
      },
    });
  });
}

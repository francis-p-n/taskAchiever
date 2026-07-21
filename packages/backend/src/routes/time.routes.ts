import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { timeEntries } from '../db/schema';
import { eq, desc, and, gte, sql } from 'drizzle-orm';

const CATEGORIES = ['quest', 'work', 'health', 'social', 'rest', 'waste'] as const;

// Baseline value of an hour per category; mood/energy deltas shift it. The
// score is a 0-100 heuristic, not money — it ranks activities against each
// other so the dashboard can name time leaks.
const CATEGORY_BASE_ROI: Record<string, number> = {
  quest: 70,
  work: 60,
  health: 75,
  social: 65,
  rest: 50,
  waste: 10,
};

function computeRoi(entry: {
  category: string;
  moodBefore?: number | null;
  moodAfter?: number | null;
  energyBefore?: number | null;
  energyAfter?: number | null;
}): number {
  let score = CATEGORY_BASE_ROI[entry.category] ?? 50;
  if (entry.moodBefore != null && entry.moodAfter != null) {
    score += (entry.moodAfter - entry.moodBefore) * 3;
  }
  if (entry.energyBefore != null && entry.energyAfter != null) {
    score += (entry.energyAfter - entry.energyBefore) * 2;
  }
  return Math.max(0, Math.min(100, Math.round(score)));
}

export default async function timeRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.post('/api/time', {
    schema: {
      body: {
        type: 'object',
        required: ['category', 'durationMinutes'],
        properties: {
          category: { type: 'string', enum: CATEGORIES as unknown as string[] },
          durationMinutes: { type: 'integer', minimum: 1, maximum: 24 * 60 },
          startTime: { type: 'string' },
          notes: { type: 'string', maxLength: 2000 },
          moodBefore: { type: 'integer', minimum: 1, maximum: 10 },
          energyBefore: { type: 'integer', minimum: 1, maximum: 10 },
          moodAfter: { type: 'integer', minimum: 1, maximum: 10 },
          energyAfter: { type: 'integer', minimum: 1, maximum: 10 },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as {
      category: string;
      durationMinutes: number;
      startTime?: string;
      notes?: string;
      moodBefore?: number;
      energyBefore?: number;
      moodAfter?: number;
      energyAfter?: number;
    };

    const startTime = data.startTime ? new Date(data.startTime) : new Date();
    if (Number.isNaN(startTime.getTime())) {
      return reply.status(400).send({
        error: 'BAD_START_TIME',
        message: 'startTime is not a valid date',
        statusCode: 400,
      });
    }

    const [entry] = await db.insert(timeEntries).values({
      userId: user.id,
      category: data.category,
      startTime,
      durationMinutes: data.durationMinutes,
      notes: data.notes,
      moodBefore: data.moodBefore,
      energyBefore: data.energyBefore,
      moodAfter: data.moodAfter,
      energyAfter: data.energyAfter,
      roiScore: computeRoi(data),
    }).returning();

    return reply.status(201).send(entry);
  });

  fastify.get('/api/time/recent', async (request, reply) => {
    const user = request.user as { id: number };
    const rows = await db.query.timeEntries.findMany({
      where: eq(timeEntries.userId, user.id),
      orderBy: [desc(timeEntries.startTime)],
      limit: 20,
    });
    return reply.send(rows);
  });

  // Per-category totals + ROI ranking over a trailing window (7d/30d/90d).
  fastify.get('/api/time/summary', async (request, reply) => {
    const user = request.user as { id: number };
    const range = (request.query as { range?: string }).range ?? '7d';
    const days = range === '90d' ? 90 : range === '30d' ? 30 : 7;
    const since = new Date(Date.now() - days * 24 * 3600 * 1000);

    const byCategory = await db
      .select({
        category: timeEntries.category,
        minutes: sql<string>`coalesce(sum(${timeEntries.durationMinutes}), 0)`,
        entries: sql<string>`count(*)`,
        avgRoi: sql<string>`coalesce(round(avg(${timeEntries.roiScore})), 0)`,
      })
      .from(timeEntries)
      .where(and(eq(timeEntries.userId, user.id), gte(timeEntries.startTime, since)))
      .groupBy(timeEntries.category)
      .orderBy(desc(sql`sum(${timeEntries.durationMinutes})`));

    const categories = byCategory.map((r) => ({
      category: r.category,
      minutes: Number(r.minutes),
      entries: Number(r.entries),
      avgRoi: Number(r.avgRoi),
    }));

    return reply.send({
      rangeDays: days,
      totalMinutes: categories.reduce((sum, c) => sum + c.minutes, 0),
      byCategory: categories,
      roiRanking: [...categories].sort((a, b) => b.avgRoi - a.avgRoi),
    });
  });
}

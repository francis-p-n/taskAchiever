import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { healthMetrics, activities } from '../db/schema';
import { eq, and, gte, lte, desc, sql } from 'drizzle-orm';

/** Logs within this window of an existing activity are the same workout. */
const DUPLICATE_WINDOW_MS = 45 * 60 * 1000;

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

    // Recent workouts (Strava + manual), newest first, for the Activity Log.
    const recent = await db.query.activities.findMany({
      where: eq(activities.userId, user.id),
      orderBy: desc(activities.startTime),
      limit: 20,
    });

    const todayActivityCalories = recent
      .filter((a) => a.startTime >= today)
      .reduce((sum, a) => sum + (a.caloriesBurned || 0), 0);

    return reply.send({
      ...(metrics || {}),
      caloriesBurned: (metrics?.caloriesBurned || 0) + todayActivityCalories,
      activities: recent,
    });
  });

  fastify.post('/api/fitness', async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as any;

    // One row per day, keyed on midnight. Manual logs accumulate; health
    // syncs send absolute daily totals with replace=true.
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const replace = data.replace === true;

    const [metric] = await db.insert(healthMetrics).values({
      userId: user.id,
      date: today,
      steps: data.steps ?? 0,
      caloriesBurned: data.caloriesBurned ?? 0,
      heartRateMin: data.heartRateMin,
      heartRateMax: data.heartRateMax,
      sleepScore: data.sleepScore,
    }).onConflictDoUpdate({
      target: [healthMetrics.userId, healthMetrics.date],
      set: {
        steps: replace
          ? data.steps ?? 0
          : sql`${healthMetrics.steps} + ${data.steps ?? 0}`,
        caloriesBurned: replace
          ? data.caloriesBurned ?? 0
          : sql`${healthMetrics.caloriesBurned} + ${data.caloriesBurned ?? 0}`,
        heartRateMin: sql`LEAST(COALESCE(${healthMetrics.heartRateMin}, 999), COALESCE(${data.heartRateMin ?? null}, 999))`,
        heartRateMax: sql`GREATEST(COALESCE(${healthMetrics.heartRateMax}, 0), COALESCE(${data.heartRateMax ?? null}, 0))`,
        sleepScore: data.sleepScore ?? sql`${healthMetrics.sleepScore}`,
        updatedAt: new Date(),
      },
    }).returning();

    // The LEAST/GREATEST sentinels leak when no HR was ever provided.
    if (metric.heartRateMin === 999) {
      await db.update(healthMetrics)
        .set({ heartRateMin: null })
        .where(and(eq(healthMetrics.userId, user.id), eq(healthMetrics.date, today)));
      metric.heartRateMin = null;
    }
    if (metric.heartRateMax === 0) {
      await db.update(healthMetrics)
        .set({ heartRateMax: null })
        .where(and(eq(healthMetrics.userId, user.id), eq(healthMetrics.date, today)));
      metric.heartRateMax = null;
    }

    return reply.status(201).send(metric);
  });

  // Individual workout from Health Connect or a manual log. Skips the insert
  // when an activity from any source already covers the same time window.
  fastify.post('/api/fitness/activity', async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as any;

    const startTime = new Date(data.startTime ?? Date.now());
    if (!data.name || isNaN(startTime.getTime())) {
      return reply.status(400).send({ error: 'name and a valid startTime are required' });
    }

    const overlapping = await db.query.activities.findFirst({
      where: and(
        eq(activities.userId, user.id),
        gte(activities.startTime, new Date(startTime.getTime() - DUPLICATE_WINDOW_MS)),
        lte(activities.startTime, new Date(startTime.getTime() + DUPLICATE_WINDOW_MS))
      ),
    });
    if (overlapping) {
      return reply.send({ duplicate: true, kept: overlapping.source });
    }

    const [activity] = await db.insert(activities).values({
      userId: user.id,
      source: data.source === 'health' ? 'health' : 'manual',
      externalId: data.externalId ?? null,
      name: String(data.name),
      sportType: data.sportType ?? null,
      startTime,
      durationSeconds: data.durationSeconds ?? 0,
      caloriesBurned: data.caloriesBurned ?? 0,
      avgHeartRate: data.avgHeartRate ?? null,
    }).onConflictDoNothing().returning();

    return reply.status(201).send(activity ?? { duplicate: true });
  });
}

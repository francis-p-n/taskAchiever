import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { healthMetrics, activities } from '../db/schema';
import { eq, and, gte, lte, desc, sql } from 'drizzle-orm';
import { isSameWorkout } from '../lib/workouts';
import { AchievementService } from '../services/achievements.service';

/** How far around a new activity to look for duplicate candidates; the
 *  actual match is interval overlap (see isSameWorkout). */
const CANDIDATE_WINDOW_MS = 6 * 60 * 60 * 1000;

export default async function fitnessRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/fitness/daily', async (request, reply) => {
    const user = request.user as { id: number };
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Merge every row for today: legacy code wrote arbitrary-timestamp rows,
    // new code upserts a midnight-keyed one — summing keeps both correct.
    const rows = await db.query.healthMetrics.findMany({
      where: and(
        eq(healthMetrics.userId, user.id),
        gte(healthMetrics.date, today)
      )
    });
    const metrics = rows.length === 0 ? null : rows.reduce((acc, r) => ({
      ...acc,
      steps: (acc.steps || 0) + (r.steps || 0),
      caloriesBurned: (acc.caloriesBurned || 0) + (r.caloriesBurned || 0),
      heartRateMin: r.heartRateMin != null && (acc.heartRateMin == null || r.heartRateMin < acc.heartRateMin)
        ? r.heartRateMin : acc.heartRateMin,
      heartRateMax: r.heartRateMax != null && (acc.heartRateMax == null || r.heartRateMax > acc.heartRateMax)
        ? r.heartRateMax : acc.heartRateMax,
      sleepScore: r.sleepScore ?? acc.sleepScore,
    }));

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

  // Body Energy: one honest 0-10 score from real watch data — last night's
  // sleep, recovery (HRV when the watch exports it, else resting HR) judged
  // against the user's own 14-day baseline, and today's movement. Null when
  // there's no data; the client hides the card rather than invent a number.
  fastify.get('/api/fitness/energy', async (request, reply) => {
    const user = request.user as { id: number };
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const baselineStart = new Date(today.getTime() - 14 * 24 * 60 * 60 * 1000);

    const rows = await db.query.healthMetrics.findMany({
      where: and(
        eq(healthMetrics.userId, user.id),
        gte(healthMetrics.date, baselineStart)
      ),
    });
    const todayRow = rows.find((r) => r.date.getTime() === today.getTime());
    const history = rows.filter((r) => r.date.getTime() !== today.getTime());

    const median = (values: number[]): number | null => {
      if (values.length < 3) return null; // not enough baseline yet
      const sorted = [...values].sort((a, b) => a - b);
      return sorted[Math.floor(sorted.length / 2)];
    };

    // Sleep: 0-4 against an 8h target.
    const sleep = todayRow?.sleepMinutes
      ? Math.min(4, (todayRow.sleepMinutes / 480) * 4)
      : null;

    // Recovery: 0-3 vs personal baseline. HRV higher = calmer; resting HR
    // lower = calmer. Banded so day-to-day noise doesn't swing the score.
    const band = (ratio: number): number =>
      ratio >= 1 ? 3 : ratio >= 0.9 ? 2 : ratio >= 0.75 ? 1 : 0;
    let recovery: number | null = null;
    let recoveryBasis: 'hrv' | 'restingHr' | null = null;
    const hrvBaseline = median(history.map((r) => r.hrvRmssd ?? 0).filter((v) => v > 0));
    const hrBaseline = median(history.map((r) => r.heartRateMin ?? 0).filter((v) => v > 0));
    if (todayRow?.hrvRmssd && hrvBaseline) {
      recovery = band(todayRow.hrvRmssd / hrvBaseline);
      recoveryBasis = 'hrv';
    } else if (todayRow?.heartRateMin && hrBaseline) {
      recovery = band(hrBaseline / todayRow.heartRateMin);
      recoveryBasis = 'restingHr';
    }

    // Movement: 0-3 against an 8k-step day.
    const activity = todayRow?.steps
      ? Math.min(3, (todayRow.steps / 8000) * 3)
      : null;

    const parts = [sleep, recovery, activity].filter((v): v is number => v !== null);
    const maxParts =
      (sleep !== null ? 4 : 0) + (recovery !== null ? 3 : 0) + (activity !== null ? 3 : 0);
    const score = parts.length > 0
      ? Math.round((parts.reduce((a, b) => a + b, 0) / maxParts) * 10)
      : null;

    return reply.send({
      score,
      components: {
        sleep: { value: sleep, max: 4, minutes: todayRow?.sleepMinutes ?? null },
        recovery: { value: recovery, max: 3, basis: recoveryBasis },
        activity: { value: activity, max: 3, steps: todayRow?.steps ?? null },
      },
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
      sleepMinutes: data.sleepMinutes,
      hrvRmssd: data.hrvRmssd,
    }).onConflictDoUpdate({
      target: [healthMetrics.userId, healthMetrics.date],
      set: {
        // Health syncs send absolute daily totals; take the max so they
        // never wipe out manual logs made the same day.
        steps: replace
          ? sql`GREATEST(${healthMetrics.steps}, ${data.steps ?? 0})`
          : sql`${healthMetrics.steps} + ${data.steps ?? 0}`,
        caloriesBurned: replace
          ? sql`GREATEST(${healthMetrics.caloriesBurned}, ${data.caloriesBurned ?? 0})`
          : sql`${healthMetrics.caloriesBurned} + ${data.caloriesBurned ?? 0}`,
        heartRateMin: sql`LEAST(COALESCE(${healthMetrics.heartRateMin}, 999), COALESCE(${data.heartRateMin ?? null}, 999))`,
        heartRateMax: sql`GREATEST(COALESCE(${healthMetrics.heartRateMax}, 0), COALESCE(${data.heartRateMax ?? null}, 0))`,
        sleepScore: data.sleepScore ?? sql`${healthMetrics.sleepScore}`,
        sleepMinutes: data.sleepMinutes ?? sql`${healthMetrics.sleepMinutes}`,
        hrvRmssd: data.hrvRmssd ?? sql`${healthMetrics.hrvRmssd}`,
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

    const candidates = await db.query.activities.findMany({
      where: and(
        eq(activities.userId, user.id),
        gte(activities.startTime, new Date(startTime.getTime() - CANDIDATE_WINDOW_MS)),
        lte(activities.startTime, new Date(startTime.getTime() + CANDIDATE_WINDOW_MS))
      ),
    });
    const overlapping = candidates.find((c) =>
      isSameWorkout(startTime, data.durationSeconds ?? 0, c.startTime, c.durationSeconds ?? 0)
    );
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

    if (!activity) return reply.send({ duplicate: true });

    const newlyUnlocked = await AchievementService.evaluate(user.id);
    return reply.status(201).send({ ...activity, newlyUnlocked });
  });
}

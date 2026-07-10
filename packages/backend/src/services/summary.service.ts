import { and, eq, gte, lt, isNotNull } from 'drizzle-orm';
import { db } from '../db';
import {
  quests,
  activities,
  healthMetrics,
  nutritionLogs,
  transactions,
} from '../db/schema';
import { cache } from '../lib/redis';

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/** Monday 00:00 UTC of the week `offset` weeks ago (0 = current week). */
export function weekStart(offset: number, now = new Date()): Date {
  const day = now.getUTCDay(); // 0 = Sunday
  const monday = new Date(Date.UTC(
    now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - ((day + 6) % 7)
  ));
  return new Date(monday.getTime() - offset * WEEK_MS);
}

export interface WeeklySummary {
  weekStart: string;
  weekEnd: string;
  quests: { completed: number; xpEarned: number; avgFulfillment: number | null; activeDays: number };
  fitness: { workouts: number; caloriesBurned: number; durationMinutes: number; avgDailySteps: number };
  nutrition: { totalCalories: number; avgDailyCalories: number; mealsLogged: number };
  spending: { totalCents: number; transactionCount: number };
}

async function computeWeek(userId: number, start: Date, end: Date): Promise<WeeklySummary> {
  const [doneQuests, weekActivities, weekHealth, weekMeals, weekSpend] = await Promise.all([
    db.query.quests.findMany({
      where: and(
        eq(quests.userId, userId),
        isNotNull(quests.completedAt),
        gte(quests.completedAt, start),
        lt(quests.completedAt, end)
      ),
    }),
    db.query.activities.findMany({
      where: and(
        eq(activities.userId, userId),
        gte(activities.startTime, start),
        lt(activities.startTime, end)
      ),
    }),
    db.query.healthMetrics.findMany({
      where: and(
        eq(healthMetrics.userId, userId),
        gte(healthMetrics.date, start),
        lt(healthMetrics.date, end)
      ),
    }),
    db.query.nutritionLogs.findMany({
      where: and(
        eq(nutritionLogs.userId, userId),
        gte(nutritionLogs.loggedAt, start),
        lt(nutritionLogs.loggedAt, end)
      ),
    }),
    db.query.transactions.findMany({
      where: and(
        eq(transactions.userId, userId),
        gte(transactions.transactionDate, start),
        lt(transactions.transactionDate, end)
      ),
    }),
  ]);

  const fulfillments = doneQuests.filter((q) => q.fulfillment != null).map((q) => q.fulfillment as number);
  const activeDays = new Set(
    doneQuests.map((q) => (q.completedAt as Date).toISOString().split('T')[0])
  ).size;

  const stepsDays = weekHealth.filter((h) => (h.steps || 0) > 0);
  const totalMealCalories = weekMeals.reduce((s, m) => s + (m.calories || 0), 0);
  const mealDays = new Set(weekMeals.map((m) => m.loggedAt.toISOString().split('T')[0])).size;

  return {
    weekStart: start.toISOString(),
    weekEnd: end.toISOString(),
    quests: {
      completed: doneQuests.length,
      xpEarned: doneQuests.reduce((s, q) => s + (q.difficulty || 1) * 10, 0),
      avgFulfillment: fulfillments.length
        ? Math.round((fulfillments.reduce((a, b) => a + b, 0) / fulfillments.length) * 10) / 10
        : null,
      activeDays,
    },
    fitness: {
      workouts: weekActivities.length,
      caloriesBurned:
        weekActivities.reduce((s, a) => s + (a.caloriesBurned || 0), 0) +
        weekHealth.reduce((s, h) => s + (h.caloriesBurned || 0), 0),
      durationMinutes: Math.round(weekActivities.reduce((s, a) => s + (a.durationSeconds || 0), 0) / 60),
      avgDailySteps: stepsDays.length
        ? Math.round(stepsDays.reduce((s, h) => s + (h.steps || 0), 0) / stepsDays.length)
        : 0,
    },
    nutrition: {
      totalCalories: totalMealCalories,
      avgDailyCalories: mealDays ? Math.round(totalMealCalories / mealDays) : 0,
      mealsLogged: weekMeals.length,
    },
    spending: {
      totalCents: weekSpend.reduce((s, t) => s + (t.amount || 0), 0),
      transactionCount: weekSpend.length,
    },
  };
}

export class SummaryService {
  /** One week's aggregates. offset 0 = the running week (short cache),
   *  past weeks are immutable (long cache). */
  static async weekly(userId: number, offset: number): Promise<WeeklySummary> {
    const key = `summary:weekly:${userId}:${offset}`;
    const cached = await cache.get(key);
    if (cached) return JSON.parse(cached);

    const start = weekStart(offset);
    const summary = await computeWeek(userId, start, new Date(start.getTime() + WEEK_MS));

    await cache.setEx(key, JSON.stringify(summary), offset === 0 ? 300 : 3600);
    return summary;
  }

  /** Per-week series, oldest first — the raw material for trend charts. */
  static async trends(userId: number, weeks: number) {
    const key = `summary:trends:${userId}:${weeks}`;
    const cached = await cache.get(key);
    if (cached) return JSON.parse(cached);

    const series = await Promise.all(
      Array.from({ length: weeks }, (_, i) => this.weekly(userId, weeks - 1 - i))
    );

    const result = { weeks: series };
    await cache.setEx(key, JSON.stringify(result), 900);
    return result;
  }
}

import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import {
  timeEntries,
  transactions,
  dailyCheckins,
  habits,
  contacts,
} from '../db/schema';
import { eq, and, gte, sql } from 'drizzle-orm';
import { generateWeeklyInsights } from '../services/ai.service';

async function timeByCategorySince(userId: number, since: Date) {
  const rows = await db
    .select({
      category: timeEntries.category,
      minutes: sql<string>`coalesce(sum(${timeEntries.durationMinutes}), 0)`,
      avgRoi: sql<string>`coalesce(round(avg(${timeEntries.roiScore})), 0)`,
    })
    .from(timeEntries)
    .where(and(eq(timeEntries.userId, userId), gte(timeEntries.startTime, since)))
    .groupBy(timeEntries.category);
  return rows.map((r) => ({
    category: r.category,
    minutes: Number(r.minutes),
    avgRoi: Number(r.avgRoi),
  }));
}

async function spentCentsSince(userId: number, since: Date) {
  const [row] = await db
    .select({ cents: sql<string>`coalesce(sum(${transactions.amount}), 0)` })
    .from(transactions)
    .where(and(eq(transactions.userId, userId), gte(transactions.transactionDate, since)));
  return Number(row?.cents ?? 0);
}

async function habitPulse(userId: number) {
  const rows = await db.query.habits.findMany({
    where: and(eq(habits.userId, userId), eq(habits.active, true)),
  });
  const today = Math.floor(Date.now() / (24 * 3600 * 1000));
  const dayOf = (d: Date) => Math.floor(d.getTime() / (24 * 3600 * 1000));
  return {
    total: rows.length,
    activeStreaks: rows.filter((h) => (h.currentStreakDays ?? 0) > 0).length,
    completedToday: rows.filter(
      (h) => h.lastCompletedAt != null && dayOf(h.lastCompletedAt) === today
    ).length,
  };
}

async function moodAvgSince(userId: number, since: Date) {
  const [row] = await db
    .select({
      mood: sql<string | null>`round(avg(coalesce(${dailyCheckins.eveningMood}, ${dailyCheckins.morningMood})), 1)`,
    })
    .from(dailyCheckins)
    .where(and(eq(dailyCheckins.userId, userId), gte(dailyCheckins.date, since)));
  return row?.mood != null ? Number(row.mood) : null;
}

async function atRiskCount(userId: number) {
  const windows: Record<string, number> = {
    close: 30, friend: 60, acquaintance: 120, professional: 90,
  };
  const rows = await db.query.contacts.findMany({ where: eq(contacts.userId, userId) });
  return rows.filter((c) => {
    if (!c.lastContactedAt) return true; // never contacted = at risk
    const days = (Date.now() - c.lastContactedAt.getTime()) / (24 * 3600 * 1000);
    return days >= (windows[c.relationshipType ?? 'friend'] ?? 60);
  }).length;
}

export default async function dashboardRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // Single-screen life summary: today's numbers across every tracked domain.
  fastify.get('/api/dashboard/daily', async (request, reply) => {
    const user = request.user as { id: number };
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayUtc = new Date(`${now.toISOString().slice(0, 10)}T00:00:00.000Z`);

    const [time, spentTodayCents, habitsPulse, checkin] = await Promise.all([
      timeByCategorySince(user.id, todayStart),
      spentCentsSince(user.id, todayStart),
      habitPulse(user.id),
      db.query.dailyCheckins.findFirst({
        where: and(eq(dailyCheckins.userId, user.id), eq(dailyCheckins.date, todayUtc)),
      }),
    ]);

    return reply.send({
      date: now.toISOString().slice(0, 10),
      time: {
        totalMinutes: time.reduce((sum, c) => sum + c.minutes, 0),
        byCategory: time,
      },
      spending: { spentTodayCents },
      habits: habitsPulse,
      checkin: checkin ?? null,
    });
  });

  // Weekly digest: aggregates the trailing 7 days and asks Claude for
  // pattern insights (heuristic fallback offline).
  fastify.get('/api/insights/weekly', async (request, reply) => {
    const user = request.user as { id: number };
    const since = new Date(Date.now() - 7 * 24 * 3600 * 1000);

    const [timeByCategory, spentWeekCents, moodAvg, habitsPulse, atRiskContacts] =
      await Promise.all([
        timeByCategorySince(user.id, since),
        spentCentsSince(user.id, since),
        moodAvgSince(user.id, since),
        habitPulse(user.id),
        atRiskCount(user.id),
      ]);

    const summary = {
      timeByCategory,
      spentWeekCents,
      moodAvg,
      activeStreaks: habitsPulse.activeStreaks,
      atRiskContacts,
    };
    const { insights, source } = await generateWeeklyInsights(summary);

    return reply.send({ ...summary, insights, source });
  });
}

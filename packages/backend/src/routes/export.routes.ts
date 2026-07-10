import { FastifyInstance } from 'fastify';
import { eq } from 'drizzle-orm';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import {
  quests,
  questSteps,
  userStats,
  activities,
  healthMetrics,
  nutritionLogs,
  transactions,
  scheduleEvents,
} from '../db/schema';

const DATASETS = {
  quests: () => quests,
  activities: () => activities,
  health: () => healthMetrics,
  nutrition: () => nutritionLogs,
  transactions: () => transactions,
  schedule: () => scheduleEvents,
} as const;

type DatasetName = keyof typeof DATASETS;

function toCsv(rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  const escape = (v: unknown): string => {
    if (v == null) return '';
    const s = v instanceof Date ? v.toISOString() : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [
    headers.join(','),
    ...rows.map((r) => headers.map((h) => escape(r[h])).join(',')),
  ].join('\n');
}

export default async function exportRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // Data portability: everything the account owns, as one JSON document or
  // one CSV per dataset. Heavier than normal reads, so tightly rate-limited.
  fastify.get('/api/export', {
    config: { rateLimit: { max: 10, timeWindow: '1 hour' } },
    schema: {
      querystring: {
        type: 'object',
        properties: {
          format: { type: 'string', enum: ['json', 'csv'], default: 'json' },
          dataset: { type: 'string', enum: Object.keys(DATASETS) },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { format, dataset } = request.query as { format: 'json' | 'csv'; dataset?: DatasetName };
    const stamp = new Date().toISOString().split('T')[0];

    if (format === 'csv') {
      const name: DatasetName = dataset || 'quests';
      const table = DATASETS[name]();
      const rows = await db.select().from(table).where(eq(table.userId, user.id));
      return reply
        .header('Content-Type', 'text/csv; charset=utf-8')
        .header('Content-Disposition', `attachment; filename="lifeos-${name}-${stamp}.csv"`)
        .send(toCsv(rows as Record<string, unknown>[]));
    }

    const [questRows, stepRows, statRows, activityRows, healthRows, mealRows, txRows, eventRows] =
      await Promise.all([
        db.select().from(quests).where(eq(quests.userId, user.id)),
        db.select({
          id: questSteps.id,
          questId: questSteps.questId,
          text: questSteps.text,
          completed: questSteps.completed,
          completedAt: questSteps.completedAt,
          createdAt: questSteps.createdAt,
        }).from(questSteps).innerJoin(quests, eq(questSteps.questId, quests.id)).where(eq(quests.userId, user.id)),
        db.select().from(userStats).where(eq(userStats.userId, user.id)),
        db.select().from(activities).where(eq(activities.userId, user.id)),
        db.select().from(healthMetrics).where(eq(healthMetrics.userId, user.id)),
        db.select().from(nutritionLogs).where(eq(nutritionLogs.userId, user.id)),
        db.select().from(transactions).where(eq(transactions.userId, user.id)),
        db.select().from(scheduleEvents).where(eq(scheduleEvents.userId, user.id)),
      ]);

    return reply
      .header('Content-Disposition', `attachment; filename="lifeos-export-${stamp}.json"`)
      .send({
        exportedAt: new Date().toISOString(),
        quests: questRows,
        questSteps: stepRows,
        stats: statRows[0] ?? null,
        activities: activityRows,
        healthMetrics: healthRows,
        nutritionLogs: mealRows,
        transactions: txRows,
        scheduleEvents: eventRows,
      });
  });
}

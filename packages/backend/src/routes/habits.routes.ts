import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { habits, habitCompletions, userStats } from '../db/schema';
import { eq, desc, and, sql } from 'drizzle-orm';

/** UTC day number — streaks compare calendar days, not 24h windows. */
function dayNumber(date: Date): number {
  return Math.floor(date.getTime() / (24 * 3600 * 1000));
}

export default async function habitRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/habits', async (request, reply) => {
    const user = request.user as { id: number };
    const rows = await db.query.habits.findMany({
      where: and(eq(habits.userId, user.id), eq(habits.active, true)),
      orderBy: [desc(habits.currentStreakDays)],
    });
    const today = dayNumber(new Date());
    return reply.send(rows.map((h) => ({
      ...h,
      completedToday: h.lastCompletedAt != null && dayNumber(h.lastCompletedAt) === today,
    })));
  });

  fastify.post('/api/habits', {
    schema: {
      body: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string', minLength: 1, maxLength: 255 },
          category: {
            type: 'string',
            enum: ['fitness', 'learning', 'spirituality', 'social', 'other'],
          },
          difficulty: { type: 'integer', minimum: 1, maximum: 5 },
          targetFrequency: { type: 'string', enum: ['daily', '3x-weekly', 'weekly'] },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as {
      name: string;
      category?: string;
      difficulty?: number;
      targetFrequency?: string;
    };

    const [habit] = await db.insert(habits).values({
      userId: user.id,
      name: data.name,
      category: data.category ?? 'fitness',
      difficulty: data.difficulty ?? 3,
      targetFrequency: data.targetFrequency ?? 'daily',
    }).returning();

    return reply.status(201).send(habit);
  });

  // Soft delete: keep history, drop from the active list.
  fastify.delete('/api/habits/:id', async (request, reply) => {
    const user = request.user as { id: number };
    const id = Number((request.params as { id: string }).id);
    const updated = await db.update(habits)
      .set({ active: false, updatedAt: new Date() })
      .where(and(eq(habits.id, id), eq(habits.userId, user.id)))
      .returning({ id: habits.id });
    if (updated.length === 0) {
      return reply.status(404).send({
        error: 'NOT_FOUND', message: 'Habit not found', statusCode: 404,
      });
    }
    return reply.send({ archived: true });
  });

  // Daily check-in. Streak rules: consecutive day extends; a 1-2 day gap is
  // absorbed by remaining freezes (one per missed day); otherwise reset to 1.
  fastify.post('/api/habits/:id/complete', {
    schema: {
      body: {
        type: 'object',
        properties: {
          notes: { type: 'string', maxLength: 2000 },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const id = Number((request.params as { id: string }).id);
    const { notes } = (request.body ?? {}) as { notes?: string };

    const habit = await db.query.habits.findFirst({
      where: and(eq(habits.id, id), eq(habits.userId, user.id), eq(habits.active, true)),
    });
    if (!habit) {
      return reply.status(404).send({
        error: 'NOT_FOUND', message: 'Habit not found', statusCode: 404,
      });
    }

    const now = new Date();
    const today = dayNumber(now);
    if (habit.lastCompletedAt != null && dayNumber(habit.lastCompletedAt) === today) {
      return reply.status(409).send({
        error: 'ALREADY_COMPLETED',
        message: 'Habit already completed today',
        statusCode: 409,
      });
    }

    let streak = 1;
    let freezesUsed = 0;
    let freezesRemaining = habit.freezesRemaining ?? 0;
    if (habit.lastCompletedAt != null) {
      const gap = today - dayNumber(habit.lastCompletedAt);
      if (gap === 1) {
        streak = (habit.currentStreakDays ?? 0) + 1;
      } else if (gap >= 2 && gap <= 3 && freezesRemaining >= gap - 1) {
        freezesUsed = gap - 1;
        freezesRemaining -= freezesUsed;
        streak = (habit.currentStreakDays ?? 0) + 1;
      }
    }
    const longest = Math.max(streak, habit.longestStreakDays ?? 0);

    const [completion] = await db.insert(habitCompletions).values({
      habitId: id,
      completedAt: now,
      notes,
      streakDay: streak,
    }).returning();

    await db.update(habits)
      .set({
        currentStreakDays: streak,
        longestStreakDays: longest,
        lastCompletedAt: now,
        freezesRemaining,
        updatedAt: now,
      })
      .where(eq(habits.id, id));

    // XP scales with difficulty; a 7-day milestone pays a bonus.
    const xp = (habit.difficulty ?? 3) * 10 + (streak % 7 === 0 ? 50 : 0);
    await db.insert(userStats)
      .values({ userId: user.id, experiencePoints: xp, updatedAt: now })
      .onConflictDoUpdate({
        target: userStats.userId,
        set: {
          experiencePoints: sql`${userStats.experiencePoints} + ${xp}`,
          updatedAt: now,
        },
      });

    return reply.status(201).send({
      ...completion,
      currentStreakDays: streak,
      longestStreakDays: longest,
      freezesUsed,
      freezesRemaining,
      xpAwarded: xp,
    });
  });

  fastify.get('/api/habits/:id/completions', async (request, reply) => {
    const user = request.user as { id: number };
    const id = Number((request.params as { id: string }).id);
    const habit = await db.query.habits.findFirst({
      where: and(eq(habits.id, id), eq(habits.userId, user.id)),
    });
    if (!habit) {
      return reply.status(404).send({
        error: 'NOT_FOUND', message: 'Habit not found', statusCode: 404,
      });
    }
    const rows = await db.query.habitCompletions.findMany({
      where: eq(habitCompletions.habitId, id),
      orderBy: [desc(habitCompletions.completedAt)],
      limit: 60,
    });
    return reply.send(rows);
  });
}

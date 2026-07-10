import { eq, and, like, isNull, gt, ne } from 'drizzle-orm';
import { db } from '../db';
import { quests, questSteps, userStats } from '../db/schema';
import { cache } from '../lib/redis';
import { TodoistService } from './todoist.service';
import { aiConfigured, estimateDifficulty, generateSteps } from './ai.service';

export class QuestService {
  static async getQuests(userId: number, includeArchived = false) {
    const cacheKey = includeArchived ? `quests:${userId}:all` : `quests:${userId}`;
    const cached = await cache.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const userQuests = await db.query.quests.findMany({
      where: includeArchived
        ? eq(quests.userId, userId)
        : and(eq(quests.userId, userId), isNull(quests.archivedAt)),
      with: {
        steps: true
      }
    });

    await cache.setEx(cacheKey, JSON.stringify(userQuests), 300);
    return userQuests;
  }

  static async getStats(userId: number) {
    const cached = await cache.get(`cache:stats:${userId}`);
    if (cached) return this.withStreakRisk(JSON.parse(cached));

    const stats = await db.query.userStats.findFirst({
      where: eq(userStats.userId, userId),
    });
    if (stats) {
      await cache.setEx(`cache:stats:${userId}`, JSON.stringify(stats), 300);
    }
    return stats ? this.withStreakRisk(stats) : stats;
  }

  /** Both list variants (active-only and archived-included) must go together. */
  static async bustQuestCache(userId: number) {
    await cache.del(`quests:${userId}`);
    await cache.del(`quests:${userId}:all`);
  }

  /** A streak is at risk when nothing has been completed yet today. Computed
   *  at read time so the cached row stays date-independent. */
  private static withStreakRisk<T extends { currentStreak?: number | null; lastActiveDate?: string | Date | null }>(stats: T) {
    const today = new Date().toISOString().split('T')[0];
    const lastActive = stats.lastActiveDate
      ? new Date(stats.lastActiveDate).toISOString().split('T')[0]
      : null;
    return {
      ...stats,
      streakAtRisk: (stats.currentStreak || 0) > 0 && lastActive !== today,
    };
  }

  static async archiveQuest(userId: number, questId: string, archived: boolean) {
    const [quest] = await db.update(quests)
      .set({ archivedAt: archived ? new Date() : null, updatedAt: new Date() })
      .where(and(eq(quests.id, questId), eq(quests.userId, userId)))
      .returning();
    if (!quest) throw new Error('Quest not found');

    await this.bustQuestCache(userId);
    return quest;
  }

  static async deleteQuest(userId: number, questId: string) {
    const removed = await db.delete(quests)
      .where(and(eq(quests.id, questId), eq(quests.userId, userId)))
      .returning({ id: quests.id });
    if (removed.length === 0) throw new Error('Quest not found');

    await this.bustQuestCache(userId);
    return { deleted: questId };
  }

  static async createQuest(userId: number, data: any) {
    const [quest] = await db.insert(quests).values({
      id: data.id || Math.random().toString(36).substring(2),
      userId,
      title: data.title,
      description: data.description,
      category: data.category,
      difficulty: data.difficulty || 1,
      dueDate: data.dueDate ? new Date(data.dueDate) : null,
      recurrence: data.recurrence === 'daily' || data.recurrence === 'weekly' ? data.recurrence : null,
      todoistId: data.todoistId,
    }).returning();

    if (data.steps && data.steps.length > 0) {
      const stepsToInsert = data.steps.map((step: any) => ({
        id: step.id || Math.random().toString(36).substring(2),
        questId: quest.id,
        text: step.text,
      }));
      await db.insert(questSteps).values(stepsToInsert);
    }

    // No difficulty given: rate it with the AI after the response so create
    // stays fast. The auto value lands on the next fetch and stays amendable.
    if (data.difficulty == null && aiConfigured()) {
      void estimateDifficulty(data.title, data.description)
        .then(async ({ difficulty, source }) => {
          if (source !== 'ai') return;
          await db.update(quests)
            .set({ difficulty, updatedAt: new Date() })
            .where(and(eq(quests.id, quest.id), isNull(quests.completedAt)));
          await this.bustQuestCache(userId);
        })
        .catch(() => {});
    }

    await this.bustQuestCache(userId);
    return this.getQuestById(userId, quest.id);
  }

  /** Partial update (difficulty amendments, edits). Only whitelisted fields. */
  static async updateQuest(userId: number, questId: string, patch: any) {
    const set: Record<string, unknown> = { updatedAt: new Date() };
    if (patch.title !== undefined) set.title = patch.title;
    if (patch.description !== undefined) set.description = patch.description;
    if (patch.category !== undefined) set.category = patch.category;
    if (patch.difficulty !== undefined) set.difficulty = patch.difficulty;
    if (patch.dueDate !== undefined) set.dueDate = patch.dueDate ? new Date(patch.dueDate) : null;
    if (patch.recurrence !== undefined) {
      set.recurrence = patch.recurrence === 'daily' || patch.recurrence === 'weekly' ? patch.recurrence : null;
    }

    const [quest] = await db.update(quests)
      .set(set)
      .where(and(eq(quests.id, questId), eq(quests.userId, userId)))
      .returning();
    if (!quest) throw new Error('Quest not found');

    await this.bustQuestCache(userId);
    return this.getQuestById(userId, questId);
  }

  /** Button-triggered AI breakdown into actionable steps. Step ids are
   *  deterministic per quest, so pressing the button twice cannot duplicate. */
  static async generateStepsForQuest(userId: number, questId: string) {
    const quest = await db.query.quests.findFirst({
      where: and(eq(quests.id, questId), eq(quests.userId, userId)),
    });
    if (!quest) throw new Error('Quest not found');

    const { steps, source } = await generateSteps(quest.title);
    if (steps.length > 0) {
      await db.insert(questSteps).values(
        steps.map((text, i) => ({
          id: `${questId}-step${i}`,
          questId,
          text,
        }))
      ).onConflictDoNothing();
    }

    await this.bustQuestCache(userId);
    return { source, quest: await this.getQuestById(userId, questId) };
  }

  static async getQuestById(userId: number, questId: string) {
    const quest = await db.query.quests.findFirst({
      where: and(eq(quests.id, questId), eq(quests.userId, userId)),
    });
    if (!quest) return null;

    const steps = await db.query.questSteps.findMany({
      where: eq(questSteps.questId, questId)
    });

    return { ...quest, steps };
  }

  static async completeQuest(userId: number, questId: string, fulfillment: number) {
    const quest = await db.query.quests.findFirst({
      where: and(eq(quests.id, questId), eq(quests.userId, userId))
    });

    if (!quest) throw new Error('Quest not found');
    if (quest.completedAt) return quest; // idempotent: no double XP

    const [updatedQuest] = await db.update(quests).set({
      completedAt: new Date(),
      fulfillment
    }).where(eq(quests.id, questId)).returning();

    await this.updateUserStats(userId, quest.difficulty || 1);

    // Recurring quests respawn: completing today's occurrence schedules the
    // next one (daily = +1 day, weekly = +7 days from the due date or now).
    if (quest.recurrence === 'daily' || quest.recurrence === 'weekly') {
      const intervalMs = (quest.recurrence === 'daily' ? 1 : 7) * 24 * 60 * 60 * 1000;
      const base = quest.dueDate ? new Date(quest.dueDate) : new Date();
      let nextDue = new Date(base.getTime() + intervalMs);
      while (nextDue.getTime() <= Date.now()) {
        nextDue = new Date(nextDue.getTime() + intervalMs);
      }
      await db.insert(quests).values({
        id: `${questId.replace(/-r\d+$/, '')}-r${nextDue.getTime()}`,
        userId,
        title: quest.title,
        description: quest.description,
        category: quest.category,
        difficulty: quest.difficulty,
        dueDate: nextDue,
        recurrence: quest.recurrence,
      }).onConflictDoNothing();
    }

    await this.bustQuestCache(userId);
    return updatedQuest;
  }

  static async uncompleteQuest(userId: number, questId: string) {
    const quest = await db.query.quests.findFirst({
      where: and(eq(quests.id, questId), eq(quests.userId, userId))
    });

    if (!quest) throw new Error('Quest not found');
    if (!quest.completedAt) return quest; // idempotent: nothing to revert

    const [updatedQuest] = await db.update(quests).set({
      completedAt: null,
      fulfillment: null
    }).where(eq(quests.id, questId)).returning();

    // Completing a recurring quest spawned the next occurrence — undo
    // removes any still-open future sibling so it doesn't double up.
    if (quest.recurrence) {
      const baseId = questId.replace(/-r\d+$/, '');
      await db.delete(quests).where(and(
        eq(quests.userId, userId),
        like(quests.id, `${baseId}-r%`),
        ne(quests.id, questId),
        isNull(quests.completedAt),
        quest.dueDate ? gt(quests.dueDate, quest.dueDate) : gt(quests.dueDate, new Date())
      ));
    }

    // If the completion was already pushed to Todoist, reopen it there.
    if (quest.todoistId && quest.todoistSyncedAt) {
      TodoistService.reopenTask(userId, quest.todoistId)
        .then(async (ok) => {
          if (ok) {
            await db.update(quests).set({ todoistSyncedAt: null }).where(eq(quests.id, questId));
          }
        })
        .catch(() => {});
    }

    // Take back the XP and completion count. Streak is left alone — it
    // can't be reliably reconstructed after the fact.
    await db.transaction(async (tx) => {
      const [stats] = await tx
        .select()
        .from(userStats)
        .where(eq(userStats.userId, userId))
        .for('update');
      if (!stats) return;

      const xpEarned = (quest.difficulty || 1) * 10;
      await tx.update(userStats).set({
        totalCompleted: Math.max(0, (stats.totalCompleted || 0) - 1),
        experiencePoints: Math.max(0, (stats.experiencePoints || 0) - xpEarned),
      }).where(eq(userStats.userId, userId));
    });

    await cache.del(`cache:stats:${userId}`);
    await this.bustQuestCache(userId);
    return updatedQuest;
  }

  private static async updateUserStats(userId: number, difficulty: number) {
    // Row-locked transaction: concurrent completions (the client fires
    // these without awaiting) must not lose XP to read-modify-write races.
    await db.transaction(async (tx) => {
      const [stats] = await tx
        .select()
        .from(userStats)
        .where(eq(userStats.userId, userId))
        .for('update');
      if (!stats) return;

      const xpEarned = difficulty * 10;
      const today = new Date().toISOString().split('T')[0];
      const lastActive = stats.lastActiveDate ? new Date(stats.lastActiveDate).toISOString().split('T')[0] : null;

      let newStreak = stats.currentStreak || 0;
      let freezes = stats.streakFreezes || 0;

      if (lastActive) {
        const diffDays = Math.floor((new Date(today).getTime() - new Date(lastActive).getTime()) / (1000 * 60 * 60 * 24));
        if (diffDays === 1) {
          newStreak += 1;
        } else if (diffDays > 1) {
          const missed = diffDays - 1;
          if (freezes >= missed) {
            freezes -= missed;
            newStreak += 1;
          } else {
            newStreak = 1;
          }
        }
      } else {
        newStreak = 1;
      }

      const longestStreak = Math.max(stats.longestStreak || 0, newStreak);

      await tx.update(userStats).set({
        totalCompleted: (stats.totalCompleted || 0) + 1,
        experiencePoints: (stats.experiencePoints || 0) + xpEarned,
        currentStreak: newStreak,
        longestStreak,
        streakFreezes: freezes,
        lastActiveDate: new Date()
      }).where(eq(userStats.userId, userId));
    });

    await cache.del(`cache:stats:${userId}`);
  }
}

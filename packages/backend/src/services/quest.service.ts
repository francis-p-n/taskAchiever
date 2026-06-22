import { eq, and } from 'drizzle-orm';
import { db } from '../db';
import { quests, questSteps, userStats } from '../db/schema';
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

export class QuestService {
  static async getQuests(userId: number) {
    const cached = await redis.get(`quests:${userId}`);
    if (cached) return JSON.parse(cached);

    const userQuests = await db.query.quests.findMany({
      where: eq(quests.userId, userId),
      with: {
        steps: true
      }
    });

    await redis.set(`quests:${userId}`, JSON.stringify(userQuests), 'EX', 300);
    return userQuests;
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

    await redis.del(`quests:${userId}`);
    return this.getQuestById(userId, quest.id);
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

    const [updatedQuest] = await db.update(quests).set({
      completedAt: new Date(),
      fulfillment
    }).where(eq(quests.id, questId)).returning();

    await this.updateUserStats(userId, quest.difficulty || 1);
    await redis.del(`quests:${userId}`);
    return updatedQuest;
  }

  private static async updateUserStats(userId: number, difficulty: number) {
    const stats = await db.query.userStats.findFirst({ where: eq(userStats.userId, userId) });
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

    await db.update(userStats).set({
      totalCompleted: (stats.totalCompleted || 0) + 1,
      experiencePoints: (stats.experiencePoints || 0) + xpEarned,
      currentStreak: newStreak,
      longestStreak,
      streakFreezes: freezes,
      lastActiveDate: new Date()
    }).where(eq(userStats.userId, userId));

    await redis.del(`cache:stats:${userId}`);
  }
}

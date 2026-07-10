import { and, eq, gte, lte, isNull, gt } from 'drizzle-orm';
import { db } from '../db';
import { quests, userStats, userSettings } from '../db/schema';
import { pushConfigured, sendToUser } from '../lib/push';

const DAY_MS = 24 * 60 * 60 * 1000;

/** Streak nudges go out in the evening, when there is still time to act. */
const STREAK_REMINDER_HOUR_UTC = 18;

// Per-process dedupe for streak nudges (userId -> date already nudged).
// Cheap and sufficient for the single-node deployment.
const streakNudged = new Map<number, string>();

async function remindersEnabled(userId: number, settingsCache: Map<number, boolean>): Promise<boolean> {
  if (!settingsCache.has(userId)) {
    const settings = await db.query.userSettings.findFirst({
      where: eq(userSettings.userId, userId),
    });
    settingsCache.set(userId, settings?.remindersEnabled !== false);
  }
  return settingsCache.get(userId)!;
}

/** Quests due in the next 24h that were never reminded: one push each. */
async function remindDueSoon() {
  const now = new Date();
  const dueSoon = await db.query.quests.findMany({
    where: and(
      isNull(quests.completedAt),
      isNull(quests.archivedAt),
      isNull(quests.reminderSentAt),
      gte(quests.dueDate, now),
      lte(quests.dueDate, new Date(now.getTime() + DAY_MS))
    ),
    limit: 200,
  });

  const settingsCache = new Map<number, boolean>();
  for (const quest of dueSoon) {
    if (!(await remindersEnabled(quest.userId, settingsCache))) continue;

    const hoursLeft = Math.max(1, Math.round(((quest.dueDate as Date).getTime() - now.getTime()) / 3_600_000));
    await sendToUser(
      quest.userId,
      'Quest due soon',
      `"${quest.title}" is due in about ${hoursLeft}h.`,
      { questId: quest.id, kind: 'due-soon' }
    );
    // Stamp regardless of delivery: a quest gets at most one due-soon nudge.
    await db.update(quests).set({ reminderSentAt: now }).where(eq(quests.id, quest.id));
  }
}

/** Evening nudge for anyone whose streak dies at midnight. */
async function remindStreakAtRisk() {
  const now = new Date();
  if (now.getUTCHours() !== STREAK_REMINDER_HOUR_UTC) return;

  const today = now.toISOString().split('T')[0];
  const atRisk = await db.query.userStats.findMany({
    where: gt(userStats.currentStreak, 0),
  });

  const settingsCache = new Map<number, boolean>();
  for (const stats of atRisk) {
    const lastActive = stats.lastActiveDate
      ? new Date(stats.lastActiveDate).toISOString().split('T')[0]
      : null;
    if (lastActive === today) continue; // already safe
    if (streakNudged.get(stats.userId) === today) continue;
    if (!(await remindersEnabled(stats.userId, settingsCache))) continue;

    await sendToUser(
      stats.userId,
      'Your streak is at risk',
      `Complete any quest today to keep your ${stats.currentStreak}-day streak alive.`,
      { kind: 'streak-at-risk' }
    );
    streakNudged.set(stats.userId, today);
  }
}

export async function runReminderCycle() {
  if (!pushConfigured()) return;
  await remindDueSoon();
  await remindStreakAtRisk();
}

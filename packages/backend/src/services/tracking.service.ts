import { eq, and, sql, inArray } from 'drizzle-orm';
import { db } from '../db';
import {
  quests,
  timeEntries,
  transactions,
  contacts,
  contactInteractions,
  userStats,
} from '../db/schema';

export const TIME_CATEGORIES = ['quest', 'work', 'health', 'social', 'rest', 'waste'] as const;

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

export function computeRoi(entry: {
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

/** Optional metadata a client can attach to a quest completion. Every field
 *  is opt-in; each tagged domain earns +5 bonus XP. */
export interface QuestTrackingInput {
  durationMinutes?: number;
  timeCategory?: string;
  moodBefore?: number;
  moodAfter?: number;
  energyBefore?: number;
  energyAfter?: number;
  spendingCents?: number;
  spendingCategory?: string;
  spendingMerchant?: string;
  contactId?: number;
  interactionType?: string;
}

const XP_PER_DOMAIN = 5;

export class TrackingService {
  /** Writes the tagged domains as linked rows, awards +5 XP per domain and
   *  records the total on the quest so an undo can revert everything. */
  static async applyQuestTracking(
    userId: number,
    questId: string,
    questTitle: string,
    tracking: QuestTrackingInput
  ): Promise<{ bonusXp: number; tagged: string[] }> {
    const tagged: string[] = [];

    const hasHealth =
      tracking.moodBefore != null || tracking.moodAfter != null ||
      tracking.energyBefore != null || tracking.energyAfter != null;
    const hasTime = tracking.durationMinutes != null && tracking.durationMinutes > 0;

    // Time and health share one time_entries row: health-only tags store a
    // zero-duration entry so the mood data lands somewhere revertable.
    if (hasTime || hasHealth) {
      const category =
        tracking.timeCategory && (TIME_CATEGORIES as readonly string[]).includes(tracking.timeCategory)
          ? tracking.timeCategory
          : 'quest';
      await db.insert(timeEntries).values({
        userId,
        questId,
        category,
        startTime: new Date(),
        durationMinutes: tracking.durationMinutes ?? 0,
        notes: questTitle,
        moodBefore: tracking.moodBefore,
        moodAfter: tracking.moodAfter,
        energyBefore: tracking.energyBefore,
        energyAfter: tracking.energyAfter,
        roiScore: computeRoi({ category, ...tracking }),
      });
      if (hasTime) tagged.push('time');
      if (hasHealth) tagged.push('health');
    }

    if (tracking.spendingCents != null && tracking.spendingCents > 0) {
      await db.insert(transactions).values({
        userId,
        questId,
        amount: tracking.spendingCents,
        category: tracking.spendingCategory ?? 'Other',
        merchant: tracking.spendingMerchant ?? questTitle,
        transactionDate: new Date(),
      });
      tagged.push('spending');
    }

    if (tracking.contactId != null && tracking.interactionType) {
      const contact = await db.query.contacts.findFirst({
        where: and(eq(contacts.id, tracking.contactId), eq(contacts.userId, userId)),
      });
      if (contact) {
        const now = new Date();
        await db.insert(contactInteractions).values({
          contactId: contact.id,
          questId,
          interactionType: tracking.interactionType,
          occurredAt: now,
          notes: questTitle,
        });
        if (!contact.lastContactedAt || now > contact.lastContactedAt) {
          await db.update(contacts)
            .set({ lastContactedAt: now, updatedAt: now })
            .where(eq(contacts.id, contact.id));
        }
        tagged.push('contact');
      }
    }

    const bonusXp = tagged.length * XP_PER_DOMAIN;
    if (bonusXp > 0) {
      await db.update(quests)
        .set({ trackingBonusXp: bonusXp })
        .where(eq(quests.id, questId));
      await db.update(userStats)
        .set({
          experiencePoints: sql`${userStats.experiencePoints} + ${bonusXp}`,
          updatedAt: new Date(),
        })
        .where(eq(userStats.userId, userId));
    }

    return { bonusXp, tagged };
  }

  /** Deletes the linked rows and takes back the bonus XP. The contact's
   *  last_contacted_at is not rewound — it can't be reconstructed reliably. */
  static async revertQuestTracking(userId: number, questId: string): Promise<void> {
    await db.delete(timeEntries)
      .where(and(eq(timeEntries.userId, userId), eq(timeEntries.questId, questId)));
    await db.delete(transactions)
      .where(and(eq(transactions.userId, userId), eq(transactions.questId, questId)));

    const owned = db
      .select({ id: contacts.id })
      .from(contacts)
      .where(eq(contacts.userId, userId));
    await db.delete(contactInteractions)
      .where(and(
        eq(contactInteractions.questId, questId),
        inArray(contactInteractions.contactId, owned)
      ));

    const quest = await db.query.quests.findFirst({
      where: and(eq(quests.id, questId), eq(quests.userId, userId)),
    });
    const bonusXp = quest?.trackingBonusXp ?? 0;
    if (bonusXp > 0) {
      await db.update(quests)
        .set({ trackingBonusXp: 0 })
        .where(eq(quests.id, questId));
      await db.update(userStats)
        .set({
          experiencePoints: sql`greatest(0, ${userStats.experiencePoints} - ${bonusXp})`,
          updatedAt: new Date(),
        })
        .where(eq(userStats.userId, userId));
    }
  }
}

import { and, eq, sql } from 'drizzle-orm';
import { db } from '../db';
import {
  activities,
  healthMetrics,
  nutritionLogs,
  transactions,
  userAchievements,
  userStats,
} from '../db/schema';

export type AchievementCategory = 'quests' | 'fitness' | 'food' | 'spending';

export interface AchievementDef {
  key: string;
  title: string;
  description: string;
  icon: string; // Flutter Material icon name, e.g. 'emoji_events'
  category: AchievementCategory;
}

/** Snapshot of the counters achievement criteria are checked against. */
interface Progress {
  totalCompleted: number;
  currentStreak: number;
  longestStreak: number;
  level: number;
  activityCount: number;
  bestBodyEnergy: number | null;
  foodLogCount: number;
  foodLogDays: number;
  spendingLogCount: number;
  hasImportedCsv: boolean;
}

const xpForLevel = (level: number) => 100 + (level - 1) * 50;
const levelFromXp = (xp: number) => {
  let level = 1;
  let remaining = xp;
  while (remaining >= xpForLevel(level)) {
    remaining -= xpForLevel(level);
    level++;
  }
  return level;
};

/** The full achievement catalog. Definitions live in code; only unlock
 *  state (see userAchievements) is persisted. */
export const ACHIEVEMENTS: (AchievementDef & { isMet: (p: Progress) => boolean })[] = [
  // Quests
  {
    key: 'quest_first_complete',
    title: 'First Step',
    description: 'Complete your first quest.',
    icon: 'flag_outlined',
    category: 'quests',
    isMet: (p) => p.totalCompleted >= 1,
  },
  {
    key: 'quest_complete_10',
    title: 'Getting Things Done',
    description: 'Complete 10 quests.',
    icon: 'checklist_outlined',
    category: 'quests',
    isMet: (p) => p.totalCompleted >= 10,
  },
  {
    key: 'quest_complete_50',
    title: 'Quest Veteran',
    description: 'Complete 50 quests.',
    icon: 'military_tech_outlined',
    category: 'quests',
    isMet: (p) => p.totalCompleted >= 50,
  },
  {
    key: 'quest_complete_200',
    title: 'Legend',
    description: 'Complete 200 quests.',
    icon: 'workspace_premium_outlined',
    category: 'quests',
    isMet: (p) => p.totalCompleted >= 200,
  },
  {
    key: 'quest_streak_7',
    title: 'On a Roll',
    description: 'Reach a 7-day streak.',
    icon: 'local_fire_department_outlined',
    category: 'quests',
    isMet: (p) => p.longestStreak >= 7,
  },
  {
    key: 'quest_streak_30',
    title: 'Unstoppable',
    description: 'Reach a 30-day streak.',
    icon: 'whatshot_outlined',
    category: 'quests',
    isMet: (p) => p.longestStreak >= 30,
  },
  {
    key: 'quest_level_5',
    title: 'Leveling Up',
    description: 'Reach level 5.',
    icon: 'star_outline',
    category: 'quests',
    isMet: (p) => p.level >= 5,
  },
  {
    key: 'quest_level_10',
    title: 'Seasoned Adventurer',
    description: 'Reach level 10.',
    icon: 'auto_awesome_outlined',
    category: 'quests',
    isMet: (p) => p.level >= 10,
  },
  // Fitness
  {
    key: 'fitness_first_activity',
    title: 'First Workout',
    description: 'Log your first activity.',
    icon: 'directions_run_outlined',
    category: 'fitness',
    isMet: (p) => p.activityCount >= 1,
  },
  {
    key: 'fitness_activity_10',
    title: 'In Motion',
    description: 'Log 10 activities.',
    icon: 'fitness_center_outlined',
    category: 'fitness',
    isMet: (p) => p.activityCount >= 10,
  },
  {
    key: 'fitness_activity_50',
    title: 'Athlete',
    description: 'Log 50 activities.',
    icon: 'sports_gymnastics_outlined',
    category: 'fitness',
    isMet: (p) => p.activityCount >= 50,
  },
  {
    key: 'fitness_body_energy_8',
    title: 'Peak Condition',
    description: 'Hit a Body Energy score of 8 or higher.',
    icon: 'bolt_outlined',
    category: 'fitness',
    isMet: (p) => (p.bestBodyEnergy ?? 0) >= 8,
  },
  // Food
  {
    key: 'food_first_log',
    title: 'First Bite',
    description: 'Log your first meal.',
    icon: 'restaurant_outlined',
    category: 'food',
    isMet: (p) => p.foodLogCount >= 1,
  },
  {
    key: 'food_log_streak_7',
    title: 'Mindful Eater',
    description: 'Log meals on 7 different days.',
    icon: 'menu_book_outlined',
    category: 'food',
    isMet: (p) => p.foodLogDays >= 7,
  },
  {
    key: 'food_log_50',
    title: 'Nutrition Nerd',
    description: 'Log 50 meals.',
    icon: 'set_meal_outlined',
    category: 'food',
    isMet: (p) => p.foodLogCount >= 50,
  },
  // Spending
  {
    key: 'spending_first_log',
    title: 'First Expense',
    description: 'Log your first expense.',
    icon: 'payments_outlined',
    category: 'spending',
    isMet: (p) => p.spendingLogCount >= 1,
  },
  {
    key: 'spending_first_import',
    title: 'Bulk Importer',
    description: 'Import a statement CSV.',
    icon: 'file_upload_outlined',
    category: 'spending',
    isMet: (p) => p.hasImportedCsv,
  },
  {
    key: 'spending_log_30',
    title: 'Budget Tracker',
    description: 'Log 30 expenses.',
    icon: 'account_balance_wallet_outlined',
    category: 'spending',
    isMet: (p) => p.spendingLogCount >= 30,
  },
];

async function loadProgress(userId: number): Promise<Progress> {
  const stats = await db.query.userStats.findFirst({ where: eq(userStats.userId, userId) });

  const [activityRow] = await db
    .select({ count: sql<string>`count(*)` })
    .from(activities)
    .where(eq(activities.userId, userId));

  const bestEnergyRows = await db.query.healthMetrics.findMany({
    where: eq(healthMetrics.userId, userId),
    columns: { hrvRmssd: true, sleepMinutes: true, steps: true },
  });
  // Cheap proxy for "ever hit a great day": highest single-day step count
  // relative to the 8k target combined with decent sleep, avoids recomputing
  // the full baseline-relative Body Energy formula here.
  const bestBodyEnergy = bestEnergyRows.length
    ? Math.max(
        0,
        ...bestEnergyRows.map((r) => {
          const sleep = r.sleepMinutes ? Math.min(4, (r.sleepMinutes / 480) * 4) : 0;
          const activity = r.steps ? Math.min(3, (r.steps / 8000) * 3) : 0;
          return Math.round(((sleep + activity) / 7) * 10);
        })
      )
    : null;

  const [foodCountRow] = await db
    .select({ count: sql<string>`count(*)` })
    .from(nutritionLogs)
    .where(eq(nutritionLogs.userId, userId));
  const [foodDaysRow] = await db
    .select({ count: sql<string>`count(distinct date(${nutritionLogs.loggedAt}))` })
    .from(nutritionLogs)
    .where(eq(nutritionLogs.userId, userId));

  const [spendingCountRow] = await db
    .select({ count: sql<string>`count(*)` })
    .from(transactions)
    .where(eq(transactions.userId, userId));
  const [importedRow] = await db
    .select({ count: sql<string>`count(*)` })
    .from(transactions)
    .where(and(eq(transactions.userId, userId), sql`${transactions.externalId} LIKE 'import-%'`));

  return {
    totalCompleted: stats?.totalCompleted ?? 0,
    currentStreak: stats?.currentStreak ?? 0,
    longestStreak: stats?.longestStreak ?? 0,
    level: levelFromXp(stats?.experiencePoints ?? 0),
    activityCount: Number(activityRow?.count ?? 0),
    bestBodyEnergy,
    foodLogCount: Number(foodCountRow?.count ?? 0),
    foodLogDays: Number(foodDaysRow?.count ?? 0),
    spendingLogCount: Number(spendingCountRow?.count ?? 0),
    hasImportedCsv: Number(importedRow?.count ?? 0) > 0,
  };
}

export class AchievementService {
  /** Checks the catalog against current progress, persists any newly-met
   *  achievements, and returns just the ones unlocked by this call. */
  static async evaluate(userId: number): Promise<AchievementDef[]> {
    const progress = await loadProgress(userId);
    const met = ACHIEVEMENTS.filter((a) => a.isMet(progress));
    if (met.length === 0) return [];

    const inserted = await db
      .insert(userAchievements)
      .values(met.map((a) => ({ userId, key: a.key })))
      .onConflictDoNothing()
      .returning({ key: userAchievements.key });

    const newlyUnlockedKeys = new Set(inserted.map((r) => r.key));
    return met.filter((a) => newlyUnlockedKeys.has(a.key));
  }

  /** Full catalog merged with this user's unlock state, grouped by category. */
  static async list(userId: number) {
    const unlocked = await db.query.userAchievements.findMany({
      where: eq(userAchievements.userId, userId),
    });
    const unlockedMap = new Map(unlocked.map((u) => [u.key, u.unlockedAt]));

    return ACHIEVEMENTS.map(({ isMet: _isMet, ...def }) => ({
      ...def,
      unlocked: unlockedMap.has(def.key),
      unlockedAt: unlockedMap.get(def.key)?.toISOString() ?? null,
    }));
  }
}

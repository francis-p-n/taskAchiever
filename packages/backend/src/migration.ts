import { readFileSync } from 'fs';
import { db } from './db';
import { users, quests, questSteps, userStats, userSettings } from './db/schema';
import path from 'path';

// This script migrates data from the v1.0.0 sidequest-data.json into Postgres

async function migrate() {
  console.log('Starting data migration from legacy JSON...');
  const jsonPath = path.join(__dirname, '../../../legacy/sidequest-data.json');
  
  let rawData;
  try {
    rawData = readFileSync(jsonPath, 'utf8');
  } catch (err) {
    console.log('No legacy data found. Skipping migration.');
    return;
  }

  const legacyData = JSON.parse(rawData);

  // 1. Create a default migrated user
  const [migratedUser] = await db.insert(users).values({
    email: 'legacy@migrated.user',
    name: 'Migrated User',
  }).returning();

  const userId = migratedUser.id;

  // 2. Settings
  await db.insert(userSettings).values({
    userId,
    todoistApiKey: legacyData.todoistApiKey || null,
    todoistProjectId: legacyData.todoistProjectId || null,
    syncEnabled: legacyData.settings?.syncEnabled ?? true,
    yearlyGoal: legacyData.settings?.yearlyGoal ?? 52,
  });

  // 3. Stats
  await db.insert(userStats).values({
    userId,
    totalCompleted: legacyData.stats?.totalCompleted || 0,
    currentStreak: legacyData.stats?.currentStreak || 0,
    longestStreak: legacyData.stats?.longestStreak || 0,
    experiencePoints: legacyData.stats?.experiencePoints || 0,
    streakFreezes: legacyData.stats?.streakFreezes || 0,
    lastActiveDate: legacyData.stats?.lastActiveDate ? new Date(legacyData.stats.lastActiveDate) : null,
  });

  // 4. Active Quests & Completed Quests
  const allQuests = [
    ...(legacyData.quests || []),
    ...(legacyData.completedQuests || [])
  ];

  for (const q of allQuests) {
    await db.insert(quests).values({
      id: q.id,
      userId,
      title: q.title,
      description: q.description || null,
      category: q.category || 'general',
      difficulty: q.difficulty || 1,
      dueDate: q.dueDate ? new Date(q.dueDate) : null,
      todoistId: q.todoistId || null,
      completedAt: q.completedAt ? new Date(q.completedAt) : null,
      fulfillment: q.fulfillment || null,
      createdAt: q.createdAt ? new Date(q.createdAt) : new Date(),
    });

    if (q.steps && q.steps.length > 0) {
      const stepsToInsert = q.steps.map((s: any) => ({
        id: s.id,
        questId: q.id,
        text: s.text,
        completed: s.completed || false,
        todoistId: s.todoistId || null,
        completedAt: s.completedAt ? new Date(s.completedAt) : null,
        createdAt: s.createdAt ? new Date(s.createdAt) : new Date(),
      }));
      await db.insert(questSteps).values(stepsToInsert);
    }
  }

  console.log(`Migration complete! Imported ${allQuests.length} quests for user ${userId}.`);
  process.exit(0);
}

migrate().catch(console.error);

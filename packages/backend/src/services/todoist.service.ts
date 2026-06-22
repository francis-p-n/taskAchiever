import { db } from '../db';
import { quests, questSteps, userSettings } from '../db/schema';
import { eq, isNotNull, and } from 'drizzle-orm';
import fetch from 'node-fetch';

const TODOIST_BASE = 'https://api.todoist.com/api/v1';

export class TodoistService {
  static async syncUser(userId: number) {
    const settings = await db.query.userSettings.findFirst({ where: eq(userSettings.userId, userId) });
    if (!settings || !settings.syncEnabled || !settings.todoistApiKey) {
      return { status: 'skipped', reason: 'Sync disabled or no API key' };
    }

    const headers = {
      'Authorization': `Bearer ${settings.todoistApiKey}`,
      'Content-Type': 'application/json'
    };

    // 1. Sync completed quests to Todoist
    const pendingQuests = await db.query.quests.findMany({
      where: and(
        eq(quests.userId, userId),
        isNotNull(quests.todoistId),
        isNotNull(quests.completedAt)
      )
    });

    for (const quest of pendingQuests) {
      try {
        await fetch(`${TODOIST_BASE}/tasks/${quest.todoistId}/close`, { method: 'POST', headers });
        console.log(`Closed Todoist task ${quest.todoistId} for quest ${quest.id}`);
      } catch (err) {
        console.error(`Failed to close Todoist task for quest ${quest.id}`, err);
      }
    }

    // 2. Fetch remote tasks and update local quests if they were closed on Todoist
    // (Requires mapping and comparing state, omitted for brevity but this is where it happens)

    return { status: 'success', synced: pendingQuests.length };
  }
}

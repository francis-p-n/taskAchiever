import { eq, and, or, isNull, isNotNull, lt } from 'drizzle-orm';
import { db } from '../db';
import { quests, userSettings } from '../db/schema';
import { cache } from '../lib/redis';

const TODOIST_BASE = 'https://api.todoist.com/api/v1';

interface TodoistTask {
  id: string | number;
  content: string;
  description?: string;
  priority?: number;
  due?: { date?: string; datetime?: string } | null;
}

type TasksPage = TodoistTask[] | { results: TodoistTask[]; next_cursor?: string | null };

interface SyncResult {
  status: 'success' | 'skipped' | 'error';
  imported?: number;
  closed?: number;
  reason?: string;
}

function mapDifficulty(priority?: number): number {
  if (priority === 4) return 3;
  if (priority === 3) return 2;
  return 1;
}

export class TodoistService {
  static async validateKey(apiKey: string): Promise<boolean> {
    try {
      const res = await fetch(`${TODOIST_BASE}/projects?limit=1`, {
        headers: { 'Authorization': `Bearer ${apiKey}` },
        signal: AbortSignal.timeout(10000),
      });
      return res.ok;
    } catch {
      return false;
    }
  }

  /** Resolves a project id from its (case-insensitive) name, e.g. "Sidequest". */
  static async findProjectByName(apiKey: string, name: string): Promise<string | null> {
    const headers = { 'Authorization': `Bearer ${apiKey}` };
    let cursor: string | null = null;
    const wanted = name.trim().toLowerCase();

    do {
      const params = new URLSearchParams({ limit: '200' });
      if (cursor) params.set('cursor', cursor);
      const res = await fetch(`${TODOIST_BASE}/projects?${params.toString()}`, {
        headers,
        signal: AbortSignal.timeout(10000),
      });
      if (!res.ok) return null;

      const page = (await res.json()) as
        | Array<{ id: string | number; name: string }>
        | { results: Array<{ id: string | number; name: string }>; next_cursor?: string | null };
      const projects = Array.isArray(page) ? page : page.results || [];
      const match = projects.find((p) => p.name.trim().toLowerCase() === wanted);
      if (match) return String(match.id);
      cursor = Array.isArray(page) ? null : page.next_cursor || null;
    } while (cursor);

    return null;
  }

  static async syncUser(userId: number): Promise<SyncResult> {
    const settings = await db.query.userSettings.findFirst({ where: eq(userSettings.userId, userId) });
    if (!settings || !settings.syncEnabled || !settings.todoistApiKey) {
      return { status: 'skipped', reason: 'Sync disabled or no API key' };
    }

    const headers = {
      'Authorization': `Bearer ${settings.todoistApiKey}`,
      'Content-Type': 'application/json',
    };

    let imported = 0;
    let closed = 0;

    try {
      // PULL: import active Todoist tasks we have not seen before.
      const tasks = await this.fetchActiveTasks(headers, settings.todoistProjectId);

      const linked = await db.query.quests.findMany({
        where: and(eq(quests.userId, userId), isNotNull(quests.todoistId)),
        columns: { todoistId: true },
      });
      const known = new Set(linked.map((q) => q.todoistId));

      for (const task of tasks) {
        const todoistId = String(task.id);
        if (known.has(todoistId)) continue;

        const due = task.due?.datetime || task.due?.date;
        const inserted = await db
          .insert(quests)
          .values({
            id: `todoist-${todoistId}`,
            userId,
            title: task.content,
            description: task.description || null,
            category: 'side',
            difficulty: mapDifficulty(task.priority),
            dueDate: due ? new Date(due) : null,
            todoistId,
          })
          .onConflictDoNothing()
          .returning({ id: quests.id });
        if (inserted.length > 0) imported++;
      }

      // PUSH: close remote tasks for quests completed locally since the last push.
      // The todoistSyncedAt watermark stops us from re-closing every completed
      // quest on each sync run.
      const toClose = await db.query.quests.findMany({
        where: and(
          eq(quests.userId, userId),
          isNotNull(quests.todoistId),
          isNotNull(quests.completedAt),
          or(isNull(quests.todoistSyncedAt), lt(quests.todoistSyncedAt, quests.completedAt))
        ),
      });

      for (const quest of toClose) {
        const res = await fetch(`${TODOIST_BASE}/tasks/${quest.todoistId}/close`, {
          method: 'POST',
          headers,
          signal: AbortSignal.timeout(10000),
        });
        if (res.ok) {
          await db.update(quests).set({ todoistSyncedAt: new Date() }).where(eq(quests.id, quest.id));
          closed++;
        }
      }
    } catch (err) {
      const reason = err instanceof Error ? err.message : 'Todoist request failed';
      return { status: 'error', reason };
    }

    await db.update(userSettings).set({ todoistLastSyncAt: new Date() }).where(eq(userSettings.userId, userId));
    await cache.del(`quests:${userId}`);

    return { status: 'success', imported, closed };
  }

  static async syncAllUsers(): Promise<void> {
    const rows = await db.query.userSettings.findMany({
      where: and(isNotNull(userSettings.todoistApiKey), eq(userSettings.syncEnabled, true)),
    });

    for (const row of rows) {
      try {
        await this.syncUser(row.userId);
      } catch (err) {
        console.error(`Todoist sync failed for user ${row.userId}`, err);
      }
    }
  }

  private static async fetchActiveTasks(
    headers: Record<string, string>,
    projectId: string | null
  ): Promise<TodoistTask[]> {
    const tasks: TodoistTask[] = [];
    let cursor: string | null = null;

    do {
      const params = new URLSearchParams({ limit: '200' });
      if (projectId) params.set('project_id', projectId);
      if (cursor) params.set('cursor', cursor);

      const res = await fetch(`${TODOIST_BASE}/tasks?${params.toString()}`, {
        headers,
        signal: AbortSignal.timeout(10000),
      });
      if (!res.ok) throw new Error(`Todoist /tasks returned ${res.status}`);

      const page = (await res.json()) as TasksPage;
      if (Array.isArray(page)) {
        tasks.push(...page);
        cursor = null;
      } else {
        tasks.push(...(page.results || []));
        cursor = page.next_cursor || null;
      }
    } while (cursor);

    return tasks;
  }
}

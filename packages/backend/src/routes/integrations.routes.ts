import { FastifyInstance } from 'fastify';
import { eq, and } from 'drizzle-orm';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { userSettings, scheduleEvents } from '../db/schema';
import { TodoistService } from '../services/todoist.service';
import { CalendarService } from '../services/calendar.service';
import { PlaidService } from '../services/plaid.service';
import { aiConfigured } from './ai.routes';

async function getOrCreateSettings(userId: number) {
  const existing = await db.query.userSettings.findFirst({ where: eq(userSettings.userId, userId) });
  if (existing) return existing;
  const [created] = await db.insert(userSettings).values({ userId }).onConflictDoNothing().returning();
  return created ?? (await db.query.userSettings.findFirst({ where: eq(userSettings.userId, userId) }))!;
}

export default async function integrationsRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // Connection status for every integration — drives the app's connect UI.
  fastify.get('/api/integrations', async (request, reply) => {
    const user = request.user as { id: number };
    const settings = await getOrCreateSettings(user.id);

    return reply.send({
      todoist: {
        connected: Boolean(settings.todoistApiKey),
        lastSyncAt: settings.todoistLastSyncAt,
        projectId: settings.todoistProjectId,
      },
      calendar: {
        connected: Boolean(settings.icalUrl),
        lastSyncAt: settings.calendarLastSyncAt,
      },
      plaid: {
        configured: PlaidService.configured(),
        connected: Boolean(settings.plaidAccessToken),
        lastSyncAt: settings.plaidLastSyncAt,
      },
      ai: { configured: aiConfigured() },
    });
  });

  // ---- Todoist ----

  fastify.post('/api/integrations/todoist', async (request, reply) => {
    const user = request.user as { id: number };
    const { apiKey, projectId, projectName } = request.body as {
      apiKey?: string;
      projectId?: string;
      projectName?: string;
    };
    if (!apiKey) return reply.status(400).send({ error: 'apiKey is required' });

    if (!(await TodoistService.validateKey(apiKey))) {
      return reply.status(401).send({ error: 'Invalid Todoist API token' });
    }

    // A project can be named (e.g. "Sidequest") instead of passing an id.
    let resolvedProjectId = projectId ?? null;
    if (!resolvedProjectId && projectName) {
      resolvedProjectId = await TodoistService.findProjectByName(apiKey, projectName);
      if (!resolvedProjectId) {
        return reply.status(404).send({ error: `No Todoist project named "${projectName}"` });
      }
    }

    await getOrCreateSettings(user.id);
    await db
      .update(userSettings)
      .set({ todoistApiKey: apiKey, todoistProjectId: resolvedProjectId, updatedAt: new Date() })
      .where(eq(userSettings.userId, user.id));

    const sync = await TodoistService.syncUser(user.id);
    return reply.send({ success: true, sync });
  });

  fastify.delete('/api/integrations/todoist', async (request, reply) => {
    const user = request.user as { id: number };
    await db
      .update(userSettings)
      .set({ todoistApiKey: null, todoistProjectId: null, updatedAt: new Date() })
      .where(eq(userSettings.userId, user.id));
    return reply.send({ success: true });
  });

  fastify.post('/api/integrations/todoist/sync', async (request, reply) => {
    const user = request.user as { id: number };
    const result = await TodoistService.syncUser(user.id);
    if (result.status === 'error') return reply.status(502).send(result);
    return reply.send(result);
  });

  // ---- Calendar (secret iCal URL — Google Calendar, Outlook, ...) ----

  fastify.post('/api/integrations/calendar', async (request, reply) => {
    const user = request.user as { id: number };
    const { icalUrl } = request.body as { icalUrl?: string };
    if (!icalUrl || !/^https?:\/\//i.test(icalUrl)) {
      return reply.status(400).send({ error: 'A valid http(s) iCal URL is required' });
    }

    if (!(await CalendarService.validateUrl(icalUrl))) {
      return reply.status(400).send({ error: 'URL did not return an iCal calendar' });
    }

    await getOrCreateSettings(user.id);
    await db
      .update(userSettings)
      .set({ icalUrl, updatedAt: new Date() })
      .where(eq(userSettings.userId, user.id));

    const sync = await CalendarService.syncUser(user.id);
    return reply.send({ success: true, sync });
  });

  fastify.delete('/api/integrations/calendar', async (request, reply) => {
    const user = request.user as { id: number };
    await db
      .update(userSettings)
      .set({ icalUrl: null, updatedAt: new Date() })
      .where(eq(userSettings.userId, user.id));
    await db
      .delete(scheduleEvents)
      .where(and(eq(scheduleEvents.userId, user.id), eq(scheduleEvents.isGoogleEvent, true)));
    return reply.send({ success: true });
  });

  fastify.post('/api/integrations/calendar/sync', async (request, reply) => {
    const user = request.user as { id: number };
    const result = await CalendarService.syncUser(user.id);
    if (result.status === 'error') return reply.status(502).send(result);
    return reply.send(result);
  });

  // ---- Plaid (bank transactions) ----

  fastify.post('/api/integrations/plaid/sync', async (request, reply) => {
    const user = request.user as { id: number };
    if (!PlaidService.configured()) {
      return reply.status(503).send({ error: 'Plaid not configured' });
    }
    const settings = await getOrCreateSettings(user.id);
    if (!settings.plaidAccessToken) {
      return reply.status(400).send({ error: 'No bank connected' });
    }
    const result = await PlaidService.syncTransactions(user.id);
    if (result.status === 'error') return reply.status(502).send(result);
    return reply.send(result);
  });
}

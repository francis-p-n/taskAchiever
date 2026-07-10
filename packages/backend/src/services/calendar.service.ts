import { eq, and, isNotNull, gte, lte, notInArray } from 'drizzle-orm';
import { db } from '../db';
import { scheduleEvents, userSettings } from '../db/schema';
import { parseIcs, expandOccurrences } from '../lib/ics';

const MAX_ICS_BYTES = 10_000_000;
const WINDOW_BEHIND_MS = 24 * 60 * 60 * 1000; // 1 day back
const WINDOW_AHEAD_MS = 14 * 24 * 60 * 60 * 1000; // 14 days ahead
const DEFAULT_EVENT_MS = 60 * 60 * 1000; // events without DTEND get 1 hour

interface SyncResult {
  status: 'success' | 'skipped' | 'error';
  imported?: number;
  reason?: string;
}

/** Syncs a user's calendar from its secret iCal URL (Google Calendar's
 *  "secret address in iCal format", Outlook published calendars, etc.)
 *  into schedule_events. No OAuth required. */
export class CalendarService {
  static async validateUrl(url: string): Promise<boolean> {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
      if (!res.ok) return false;
      const length = Number(res.headers.get('content-length') || 0);
      if (length > MAX_ICS_BYTES) return false;
      const text = await res.text();
      return text.includes('BEGIN:VCALENDAR');
    } catch {
      return false;
    }
  }

  static async syncUser(userId: number): Promise<SyncResult> {
    const settings = await db.query.userSettings.findFirst({ where: eq(userSettings.userId, userId) });
    if (!settings || !settings.icalUrl) {
      return { status: 'skipped', reason: 'No calendar URL configured' };
    }

    const windowStart = new Date(Date.now() - WINDOW_BEHIND_MS);
    const windowEnd = new Date(Date.now() + WINDOW_AHEAD_MS);

    try {
      const res = await fetch(settings.icalUrl, { signal: AbortSignal.timeout(10000) });
      if (!res.ok) return { status: 'error', reason: `Calendar URL returned ${res.status}` };
      const text = await res.text();
      if (text.length > MAX_ICS_BYTES) return { status: 'error', reason: 'Calendar feed too large' };

      const events = parseIcs(text);
      const seen: string[] = [];
      let imported = 0;

      for (const ev of events) {
        const occurrences = expandOccurrences(ev, windowStart, windowEnd);
        for (const occ of occurrences) {
          const externalId = ev.rrule ? `${ev.uid}:${occ.start.toISOString()}` : ev.uid;
          seen.push(externalId);
          await db
            .insert(scheduleEvents)
            .values({
              userId,
              title: ev.summary,
              startTime: occ.start,
              endTime: occ.end ?? new Date(occ.start.getTime() + DEFAULT_EVENT_MS),
              isGoogleEvent: true,
              externalId,
            })
            .onConflictDoUpdate({
              target: [scheduleEvents.userId, scheduleEvents.externalId],
              set: {
                title: ev.summary,
                startTime: occ.start,
                endTime: occ.end ?? new Date(occ.start.getTime() + DEFAULT_EVENT_MS),
              },
            });
          imported++;
        }
      }

      // Remove synced events in the window that vanished from the feed
      // (cancelled upstream). Manual events (isGoogleEvent = false) are kept.
      if (seen.length > 0) {
        await db
          .delete(scheduleEvents)
          .where(
            and(
              eq(scheduleEvents.userId, userId),
              eq(scheduleEvents.isGoogleEvent, true),
              gte(scheduleEvents.startTime, windowStart),
              lte(scheduleEvents.startTime, windowEnd),
              notInArray(scheduleEvents.externalId, seen)
            )
          );
      }

      await db
        .update(userSettings)
        .set({ calendarLastSyncAt: new Date(), updatedAt: new Date() })
        .where(eq(userSettings.userId, userId));

      return { status: 'success', imported };
    } catch (err: any) {
      return { status: 'error', reason: err?.message || 'Calendar sync failed' };
    }
  }

  static async syncAllUsers(): Promise<void> {
    const rows = await db.query.userSettings.findMany({
      where: isNotNull(userSettings.icalUrl),
    });
    for (const row of rows) {
      try {
        await this.syncUser(row.userId);
      } catch (err) {
        console.error(`Calendar sync failed for user ${row.userId}`, err);
      }
    }
  }
}

import { eq, and, ne, gte, lte, inArray } from 'drizzle-orm';
import { db } from '../db';
import { activities, userSettings } from '../db/schema';
import { isSameWorkout } from '../lib/workouts';

const STRAVA_OAUTH = 'https://www.strava.com/oauth';
const STRAVA_API = 'https://www.strava.com/api/v3';

/** How far around a Strava activity to look for duplicate candidates; the
 *  actual match is interval overlap (see isSameWorkout), not this window. */
const CANDIDATE_WINDOW_MS = 6 * 60 * 60 * 1000;

/** Cap per-activity detail fetches (for calories) so one sync can't crawl
 *  through hundreds of Strava API calls. */
const MAX_DETAIL_FETCHES = 25;

interface TokenResponse {
  access_token: string;
  refresh_token: string;
  expires_at: number; // epoch seconds
  athlete?: { id: number };
}

interface StravaActivity {
  id: number;
  name: string;
  sport_type?: string;
  type?: string;
  start_date: string;
  elapsed_time?: number;
  distance?: number;
  average_heartrate?: number;
  kilojoules?: number;
  calories?: number;
}

interface SyncResult {
  status: 'success' | 'skipped' | 'error';
  imported?: number;
  deduped?: number;
  reason?: string;
}

export class StravaService {
  static configured(): boolean {
    return Boolean(process.env.STRAVA_CLIENT_ID && process.env.STRAVA_CLIENT_SECRET);
  }

  static authUrl(state: string, redirectUri: string): string {
    const params = new URLSearchParams({
      client_id: process.env.STRAVA_CLIENT_ID!,
      redirect_uri: redirectUri,
      response_type: 'code',
      approval_prompt: 'auto',
      scope: 'activity:read_all',
      state,
    });
    return `${STRAVA_OAUTH}/authorize?${params.toString()}`;
  }

  /** Exchanges the OAuth code and stores tokens for the user. */
  static async connect(userId: number, code: string): Promise<boolean> {
    const res = await fetch(`${STRAVA_OAUTH}/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.STRAVA_CLIENT_ID,
        client_secret: process.env.STRAVA_CLIENT_SECRET,
        code,
        grant_type: 'authorization_code',
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return false;
    const token = (await res.json()) as TokenResponse;

    await db.insert(userSettings).values({ userId }).onConflictDoNothing();
    await db
      .update(userSettings)
      .set({
        stravaAthleteId: token.athlete ? String(token.athlete.id) : null,
        stravaAccessToken: token.access_token,
        stravaRefreshToken: token.refresh_token,
        stravaExpiresAt: new Date(token.expires_at * 1000),
        updatedAt: new Date(),
      })
      .where(eq(userSettings.userId, userId));
    return true;
  }

  static async disconnect(userId: number): Promise<void> {
    await db
      .update(userSettings)
      .set({
        stravaAthleteId: null,
        stravaAccessToken: null,
        stravaRefreshToken: null,
        stravaExpiresAt: null,
        updatedAt: new Date(),
      })
      .where(eq(userSettings.userId, userId));
    await db
      .delete(activities)
      .where(and(eq(activities.userId, userId), eq(activities.source, 'strava')));
  }

  private static async accessToken(userId: number): Promise<string | null> {
    const settings = await db.query.userSettings.findFirst({
      where: eq(userSettings.userId, userId),
    });
    if (!settings?.stravaRefreshToken) return null;

    const stillValid =
      settings.stravaAccessToken &&
      settings.stravaExpiresAt &&
      settings.stravaExpiresAt.getTime() > Date.now() + 60_000;
    if (stillValid) return settings.stravaAccessToken;

    const res = await fetch(`${STRAVA_OAUTH}/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.STRAVA_CLIENT_ID,
        client_secret: process.env.STRAVA_CLIENT_SECRET,
        grant_type: 'refresh_token',
        refresh_token: settings.stravaRefreshToken,
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return null;
    const token = (await res.json()) as TokenResponse;

    await db
      .update(userSettings)
      .set({
        stravaAccessToken: token.access_token,
        stravaRefreshToken: token.refresh_token,
        stravaExpiresAt: new Date(token.expires_at * 1000),
        updatedAt: new Date(),
      })
      .where(eq(userSettings.userId, userId));
    return token.access_token;
  }

  static async syncUser(userId: number): Promise<SyncResult> {
    if (!this.configured()) return { status: 'skipped', reason: 'Strava not configured' };

    const settings = await db.query.userSettings.findFirst({
      where: eq(userSettings.userId, userId),
    });
    if (!settings?.stravaRefreshToken) {
      return { status: 'skipped', reason: 'Strava not connected' };
    }

    const token = await this.accessToken(userId);
    if (!token) return { status: 'error', reason: 'Could not refresh Strava token' };

    // Pull everything since the last sync (first sync: the last 30 days).
    const since = settings.stravaLastSyncAt
      ? settings.stravaLastSyncAt.getTime()
      : Date.now() - 30 * 24 * 60 * 60 * 1000;

    let imported = 0;
    let deduped = 0;

    try {
      const params = new URLSearchParams({
        after: String(Math.floor(since / 1000)),
        per_page: '100',
      });
      const res = await fetch(`${STRAVA_API}/athlete/activities?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(15000),
      });
      if (!res.ok) return { status: 'error', reason: `Strava returned ${res.status}` };
      const list = (await res.json()) as StravaActivity[];

      let detailFetches = 0;
      for (const item of list) {
        const startTime = new Date(item.start_date);

        // The list endpoint omits calories — fetch the detail for new rows.
        let calories = item.calories ?? null;
        if (calories == null && detailFetches < MAX_DETAIL_FETCHES) {
          detailFetches++;
          try {
            const detailRes = await fetch(`${STRAVA_API}/activities/${item.id}`, {
              headers: { Authorization: `Bearer ${token}` },
              signal: AbortSignal.timeout(15000),
            });
            if (detailRes.ok) {
              const detail = (await detailRes.json()) as StravaActivity;
              calories = detail.calories ?? null;
            }
          } catch {
            // detail fetch is best-effort; kilojoules fallback below
          }
        }
        if (calories == null && item.kilojoules) calories = Math.round(item.kilojoules);

        const inserted = await db
          .insert(activities)
          .values({
            userId,
            source: 'strava',
            externalId: String(item.id),
            name: item.name,
            sportType: item.sport_type || item.type || null,
            startTime,
            durationSeconds: item.elapsed_time ?? 0,
            distanceMeters: item.distance != null ? Math.round(item.distance) : null,
            caloriesBurned: calories ?? 0,
            avgHeartRate:
              item.average_heartrate != null ? Math.round(item.average_heartrate) : null,
          })
          .onConflictDoUpdate({
            target: [activities.userId, activities.source, activities.externalId],
            set: {
              name: item.name,
              startTime,
              durationSeconds: item.elapsed_time ?? 0,
              caloriesBurned: calories ?? 0,
            },
          })
          .returning({ id: activities.id });
        imported++;

        // Same workout logged twice (manually or via health sync): a
        // duplicate is a non-Strava activity whose time interval actually
        // overlaps this one — not merely something nearby. Strava wins.
        const candidates = await db.query.activities.findMany({
          where: and(
            eq(activities.userId, userId),
            ne(activities.source, 'strava'),
            gte(activities.startTime, new Date(startTime.getTime() - CANDIDATE_WINDOW_MS)),
            lte(activities.startTime, new Date(startTime.getTime() + CANDIDATE_WINDOW_MS))
          ),
        });
        const duplicateIds = candidates
          .filter((c) =>
            isSameWorkout(
              startTime,
              item.elapsed_time ?? 0,
              c.startTime,
              c.durationSeconds ?? 0
            )
          )
          .map((c) => c.id);
        if (duplicateIds.length > 0) {
          await db.delete(activities).where(inArray(activities.id, duplicateIds));
          deduped += duplicateIds.length;
        }
      }

      await db
        .update(userSettings)
        .set({ stravaLastSyncAt: new Date(), updatedAt: new Date() })
        .where(eq(userSettings.userId, userId));

      return { status: 'success', imported, deduped };
    } catch (err: any) {
      return { status: 'error', reason: err?.message || 'Strava sync failed' };
    }
  }
}

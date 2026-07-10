// End-to-end test of the lifeOS backend integrations.
// Prereq: backend running on API_BASE (default http://127.0.0.1:3000).
// Uses a dedicated throwaway user and deletes it (cascade) at the end.
// Run: node scripts/e2e.mjs
import 'dotenv/config';
import http from 'node:http';
import pg from 'pg';

const API = process.env.API_BASE || 'http://127.0.0.1:3000';
const TEST_EMAIL = 'e2e-test@lifeos.local';
const ICS_PORT = 8787;

let token = null;
let passed = 0;
let failed = 0;
const failures = [];

function check(name, cond, detail = '') {
  if (cond) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    failures.push(name);
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

async function api(method, path, body) {
  const res = await fetch(`${API}/api${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch {}
  return { status: res.status, data };
}

// ---- ICS fixture: served from an in-process HTTP server ----
function icsDate(d) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}T${p(d.getHours())}${p(d.getMinutes())}00`;
}

function buildIcs() {
  const now = new Date();
  const todayAt = (h) => new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, 0, 0);
  const tomorrow = new Date(todayAt(9).getTime() + 24 * 3600 * 1000);
  const lastWeek = new Date(todayAt(7).getTime() - 7 * 24 * 3600 * 1000);
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//lifeOS e2e//EN',
    // 1. Plain event later today
    'BEGIN:VEVENT',
    'UID:e2e-single-today',
    'SUMMARY:E2E Team Meeting',
    `DTSTART:${icsDate(todayAt(15))}`,
    `DTEND:${icsDate(todayAt(16))}`,
    'END:VEVENT',
    // 2. Daily recurring event started last week — must appear today
    'BEGIN:VEVENT',
    'UID:e2e-daily-standup',
    'SUMMARY:E2E Daily Standup',
    `DTSTART:${icsDate(lastWeek)}`,
    `DTEND:${icsDate(new Date(lastWeek.getTime() + 30 * 60000))}`,
    'RRULE:FREQ=DAILY',
    'END:VEVENT',
    // 3. Daily recurring with TODAY excluded — must NOT appear today
    'BEGIN:VEVENT',
    'UID:e2e-excluded',
    'SUMMARY:E2E Excluded Session',
    `DTSTART:${icsDate(new Date(todayAt(11).getTime() - 3 * 24 * 3600 * 1000))}`,
    `DTEND:${icsDate(new Date(todayAt(11).getTime() - 3 * 24 * 3600 * 1000 + 30 * 60000))}`,
    'RRULE:FREQ=DAILY',
    `EXDATE:${icsDate(todayAt(11))}`,
    'END:VEVENT',
    // 4. Event tomorrow (should sync but not show in /schedule/today)
    'BEGIN:VEVENT',
    'UID:e2e-tomorrow',
    'SUMMARY:E2E Tomorrow Event',
    `DTSTART:${icsDate(tomorrow)}`,
    `DTEND:${icsDate(new Date(tomorrow.getTime() + 3600 * 1000))}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
}

async function main() {
  console.log('== lifeOS backend e2e ==');

  // Local calendar feed
  const icsServer = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/calendar' });
    res.end(buildIcs());
  });
  await new Promise((r) => icsServer.listen(ICS_PORT, '127.0.0.1', r));

  try {
    // -- health + auth --
    const health = await api('GET', '/health');
    check('health endpoint', health.status === 200 && health.data?.status === 'ok');

    token = null;
    const noAuth = await api('GET', '/integrations');
    check('integrations rejects unauthenticated', noAuth.status === 401);

    const login = await fetch(`${API}/api/auth/dev`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: TEST_EMAIL, name: 'E2E Bot' }),
    }).then((r) => r.json());
    token = login.token;
    check('dev auth issues token', Boolean(token));

    // -- integrations status (fresh user) --
    const st0 = await api('GET', '/integrations');
    check('integrations status shape', st0.status === 200 && st0.data?.todoist && st0.data?.calendar && st0.data?.plaid && st0.data?.ai);
    check('fresh user: nothing connected', st0.data?.todoist?.connected === false && st0.data?.calendar?.connected === false && st0.data?.plaid?.connected === false);

    // -- calendar integration (real HTTP ICS feed) --
    const badUrl = await api('POST', '/integrations/calendar', { icalUrl: 'not-a-url' });
    check('calendar rejects malformed URL', badUrl.status === 400);

    const notIcs = await api('POST', '/integrations/calendar', { icalUrl: `${API}/api/health` });
    check('calendar rejects non-ICS URL', notIcs.status === 400);

    const connect = await api('POST', '/integrations/calendar', { icalUrl: `http://127.0.0.1:${ICS_PORT}/cal.ics` });
    check('calendar connect + initial sync', connect.status === 200 && connect.data?.sync?.status === 'success', JSON.stringify(connect.data));
    check('calendar sync imported occurrences', (connect.data?.sync?.imported ?? 0) >= 3, `imported=${connect.data?.sync?.imported}`);

    const today = await api('GET', '/schedule/today');
    const titles = (today.data ?? []).map((e) => e.title);
    check('today has single event', titles.includes('E2E Team Meeting'), titles.join(', '));
    check('today has recurring instance', titles.includes('E2E Daily Standup'));
    check('EXDATE occurrence excluded', !titles.includes('E2E Excluded Session'));
    check('tomorrow event not in today', !titles.includes('E2E Tomorrow Event'));

    const resync = await api('POST', '/integrations/calendar/sync');
    check('re-sync succeeds (idempotent)', resync.status === 200 && resync.data?.status === 'success');
    const today2 = await api('GET', '/schedule/today');
    const meetings = (today2.data ?? []).filter((e) => e.title === 'E2E Team Meeting');
    check('re-sync does not duplicate events', meetings.length === 1, `count=${meetings.length}`);

    const st1 = await api('GET', '/integrations');
    check('calendar shows connected + lastSyncAt', st1.data?.calendar?.connected === true && Boolean(st1.data?.calendar?.lastSyncAt));

    // -- todoist: validation path (no real token available) --
    const badTodoist = await api('POST', '/integrations/todoist', { apiKey: 'bogus-token-123' });
    check('todoist rejects invalid token', badTodoist.status === 401);
    const noKey = await api('POST', '/integrations/todoist', {});
    check('todoist requires apiKey', noKey.status === 400);
    const todoistSync = await api('POST', '/integrations/todoist/sync');
    check('todoist sync skips when unconnected', todoistSync.status === 200 && todoistSync.data?.status === 'skipped');

    // -- plaid: env-gated paths --
    const plaidLink = await api('POST', '/plaid/create-link-token');
    check('plaid link 503 when unconfigured', plaidLink.status === 503);
    const plaidSync = await api('POST', '/integrations/plaid/sync');
    check('plaid sync 503 when unconfigured', plaidSync.status === 503);
    const webhook = await fetch(`${API}/api/plaid/webhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ webhook_type: 'TRANSACTIONS', webhook_code: 'SYNC_UPDATES_AVAILABLE', item_id: 'nope' }),
    });
    check('plaid webhook always 200', webhook.status === 200);

    // -- AI roadmap (fallback path without ANTHROPIC_API_KEY, real call with) --
    const ai = await api('POST', '/ai/generate-roadmap', { title: 'Learn the violin' });
    check('ai roadmap returns steps', ai.status === 200 && Array.isArray(ai.data?.steps) && ai.data.steps.length >= 3, JSON.stringify(ai.data));
    check('ai roadmap declares source', ai.data?.source === 'ai' || ai.data?.source === 'fallback');
    const aiEmpty = await api('POST', '/ai/generate-roadmap', { title: '' });
    check('ai roadmap 400 on empty title', aiEmpty.status === 400);

    // -- quests + stats round trip --
    const quest = await api('POST', '/quests', { title: 'E2E Quest', difficulty: 2, category: 'test' });
    check('quest created', quest.status === 201 && quest.data?.id);
    const qid = quest.data?.id;
    const complete = await api('POST', `/quests/${qid}/complete`, { fulfillment: 3 });
    check('quest completes', complete.status === 200 && Boolean(complete.data?.completedAt));
    const completeAgain = await api('POST', `/quests/${qid}/complete`, { fulfillment: 3 });
    check('completion is idempotent', completeAgain.status === 200);
    const stats = await api('GET', '/stats');
    check('stats award XP once (difficulty 2 → 20)', stats.data?.experiencePoints === 20, `xp=${stats.data?.experiencePoints}`);

    // -- spending: entry + live summary --
    await api('POST', '/spending', { amount: 1250, category: 'Food', merchant: 'E2E Cafe' });
    await api('POST', '/spending', { amount: 4300, category: 'Transport', merchant: 'E2E Rail' });
    const summary = await api('GET', '/spending/summary');
    check('spending summary totals', summary.data?.spentTodayCents === 5550 && summary.data?.spentMonthCents === 5550, JSON.stringify(summary.data));
    const cats = Object.fromEntries((summary.data?.byCategory ?? []).map((c) => [c.category, c.cents]));
    check('spending summary by category', cats['Food'] === 1250 && cats['Transport'] === 4300, JSON.stringify(cats));

    // -- food + fitness round trips --
    await api('POST', '/food', { mealType: 'Lunch', calories: 640, protein: 40, carbs: 60, fats: 20 });
    const food = await api('GET', '/food/today');
    check('food log round-trips', (food.data ?? []).some((l) => l.mealType === 'Lunch' && l.calories === 640));

    await api('POST', '/fitness', { steps: 4200, caloriesBurned: 310, heartRateMin: 58, heartRateMax: 142 });
    const fit = await api('GET', '/fitness/daily');
    check('fitness log round-trips', fit.data?.steps === 4200 && fit.data?.caloriesBurned === 310, JSON.stringify(fit.data));

    // -- calendar disconnect removes synced events, keeps manual ones --
    await api('POST', '/schedule', {
      title: 'E2E Manual Event',
      startTime: new Date().toISOString(),
      endTime: new Date(Date.now() + 3600e3).toISOString(),
    });
    const disc = await api('DELETE', '/integrations/calendar');
    check('calendar disconnect', disc.status === 200);
    const after = await api('GET', '/schedule/today');
    const afterTitles = (after.data ?? []).map((e) => e.title);
    check('synced events removed on disconnect', !afterTitles.includes('E2E Team Meeting'), afterTitles.join(', '));
    check('manual events survive disconnect', afterTitles.includes('E2E Manual Event'));
    const st2 = await api('GET', '/integrations');
    check('calendar shows disconnected', st2.data?.calendar?.connected === false);
  } finally {
    icsServer.close();
    // Cleanup: delete the throwaway user; FK cascades remove all its data.
    const connectionString =
      process.env.DATABASE_URL || 'postgres://life_achiever:password@localhost:5432/life_achiever';
    const pool = new pg.Pool({
      connectionString,
      ssl: connectionString.includes('localhost') ? undefined : { rejectUnauthorized: false },
      max: 1,
    });
    const del = await pool.query('DELETE FROM users WHERE email = $1', [TEST_EMAIL]);
    console.log(`cleanup: removed test user (${del.rowCount} row)`);
    await pool.end();
  }

  console.log(`\n== ${passed} passed, ${failed} failed ==`);
  if (failures.length) console.log('failures:', failures.join(' | '));
  process.exit(failed ? 1 : 0);
}

main().catch((err) => {
  console.error('e2e crashed:', err);
  process.exit(1);
});

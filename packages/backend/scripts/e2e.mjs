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

    // -- time tracking: entry + ROI + summary --
    const badTime = await api('POST', '/time', { category: 'nonsense', durationMinutes: 30 });
    check('time rejects unknown category', badTime.status === 400);
    const timeEntry = await api('POST', '/time', {
      category: 'work', durationMinutes: 90, notes: 'E2E deep work',
      moodBefore: 7, moodAfter: 6, energyBefore: 8, energyAfter: 5,
    });
    // ROI heuristic: base 60 + (6-7)*3 + (5-8)*2 = 51
    check('time entry created with ROI', timeEntry.status === 201 && timeEntry.data?.roiScore === 51, `roi=${timeEntry.data?.roiScore}`);
    await api('POST', '/time', { category: 'health', durationMinutes: 60 });
    const timeSummary = await api('GET', '/time/summary?range=7d');
    check('time summary totals', timeSummary.data?.totalMinutes === 150, JSON.stringify(timeSummary.data));
    const timeCats = Object.fromEntries((timeSummary.data?.byCategory ?? []).map((c) => [c.category, c.minutes]));
    check('time summary by category', timeCats['work'] === 90 && timeCats['health'] === 60, JSON.stringify(timeCats));
    check('time ROI ranking present', Array.isArray(timeSummary.data?.roiRanking) && timeSummary.data.roiRanking.length === 2);

    // -- daily check-ins: morning/evening halves upsert independently --
    const morning = await api('POST', '/checkins', { morningMood: 8, morningEnergy: 7, morningStress: 3, sleepMinutes: 450 });
    check('morning check-in saved', morning.status === 201 && morning.data?.morningMood === 8);
    const evening = await api('POST', '/checkins', { eveningMood: 6, eveningEnergy: 5, eveningStress: 4 });
    check('evening upsert keeps morning', evening.status === 201 && evening.data?.morningMood === 8 && evening.data?.eveningMood === 6, JSON.stringify(evening.data));
    const checkins = await api('GET', '/checkins/recent?days=14');
    check('check-in history + averages', checkins.data?.checkins?.length === 1 && checkins.data?.averages?.mood === 6, JSON.stringify(checkins.data?.averages));
    const badCheckin = await api('POST', '/checkins', { date: 'not-a-date', morningMood: 5 });
    check('check-in rejects bad date', badCheckin.status === 400);

    // -- relationships: contact + interaction + engagement --
    const contact = await api('POST', '/contacts', { name: 'E2E Friend', relationshipType: 'close' });
    check('contact created', contact.status === 201 && contact.data?.id);
    check('never-contacted is at risk', contact.data?.atRisk === true && contact.data?.engagementScore === 0);
    const cid = contact.data?.id;
    const atRisk0 = await api('GET', '/contacts/at-risk');
    check('at-risk lists fresh contact', (atRisk0.data ?? []).some((c) => c.id === cid));
    const interaction = await api('POST', `/contacts/${cid}/interactions`, { interactionType: 'meet', depthScore: 4, notes: 'coffee' });
    check('interaction logged', interaction.status === 201);
    const contactsAfter = await api('GET', '/contacts');
    const friend = (contactsAfter.data ?? []).find((c) => c.id === cid);
    check('interaction bumps engagement', friend?.atRisk === false && friend?.engagementScore >= 95, `score=${friend?.engagementScore}`);
    const atRisk1 = await api('GET', '/contacts/at-risk');
    check('at-risk clears after contact', !(atRisk1.data ?? []).some((c) => c.id === cid));
    const badInteraction = await api('POST', '/contacts/999999/interactions', { interactionType: 'call' });
    check('interaction 404 on unknown contact', badInteraction.status === 404);

    // -- habits: streaks, duplicate guard, XP --
    const habit = await api('POST', '/habits', { name: 'E2E Fasted Run', category: 'fitness', difficulty: 4 });
    check('habit created', habit.status === 201 && habit.data?.id);
    const hid = habit.data?.id;
    const done = await api('POST', `/habits/${hid}/complete`, { notes: 'first' });
    check('habit completion starts streak', done.status === 201 && done.data?.currentStreakDays === 1, JSON.stringify(done.data));
    check('habit completion awards XP', done.data?.xpAwarded === 40, `xp=${done.data?.xpAwarded}`);
    const doneAgain = await api('POST', `/habits/${hid}/complete`);
    check('same-day completion blocked', doneAgain.status === 409);
    const habitList = await api('GET', '/habits');
    const h = (habitList.data ?? []).find((x) => x.id === hid);
    check('habit list shows completedToday', h?.completedToday === true && h?.currentStreakDays === 1);
    const statsAfterHabit = await api('GET', '/stats');
    check('habit XP lands in stats (20 quest + 40 habit)', statsAfterHabit.data?.experiencePoints === 60, `xp=${statsAfterHabit.data?.experiencePoints}`);
    const archived = await api('DELETE', `/habits/${hid}`);
    check('habit archives', archived.status === 200 && archived.data?.archived === true);
    const habitList2 = await api('GET', '/habits');
    check('archived habit leaves list', !(habitList2.data ?? []).some((x) => x.id === hid));

    // -- unified dashboard + weekly insights --
    const dash = await api('GET', '/dashboard/daily');
    check('dashboard aggregates time', dash.data?.time?.totalMinutes === 150, JSON.stringify(dash.data?.time));
    check('dashboard aggregates spending', dash.data?.spending?.spentTodayCents === 5550);
    check('dashboard includes check-in', dash.data?.checkin?.morningMood === 8);
    const insights = await api('GET', '/insights/weekly');
    check('weekly insights returned', insights.status === 200 && Array.isArray(insights.data?.insights) && insights.data.insights.length >= 1, JSON.stringify(insights.data?.insights));
    check('weekly insights declare source', insights.data?.source === 'ai' || insights.data?.source === 'fallback');
    check('weekly insights carry data', insights.data?.spentWeekCents === 5550 && insights.data?.moodAvg === 6);

    // -- quest-centric tracking: inline tags, bonus XP, full undo revert --
    const tq = await api('POST', '/quests', { title: 'E2E Tracked Quest', difficulty: 3, category: 'social' });
    check('tracked quest created', tq.status === 201 && tq.data?.id);
    const tqid = tq.data?.id;
    const tqComplete = await api('POST', `/quests/${tqid}/complete`, {
      fulfillment: 4,
      tracking: {
        durationMinutes: 30, timeCategory: 'social',
        moodBefore: 6, moodAfter: 8,
        spendingCents: 1500, spendingCategory: 'Food',
        contactId: cid, interactionType: 'meet',
      },
    });
    check('inline tracking tags all 4 domains', tqComplete.status === 200 && tqComplete.data?.trackingBonusXp === 20, JSON.stringify({ bonus: tqComplete.data?.trackingBonusXp, tagged: tqComplete.data?.tagged }));
    const statsTagged = await api('GET', '/stats');
    check('quest + tag XP (60 + 30 + 20)', statsTagged.data?.experiencePoints === 110, `xp=${statsTagged.data?.experiencePoints}`);
    const timeRecent = await api('GET', '/time/recent');
    check('tagged time entry linked to quest', (timeRecent.data ?? []).some((e) => e.questId === tqid && e.durationMinutes === 30));
    const spendTagged = await api('GET', '/spending/summary');
    check('tagged spending lands in summary', spendTagged.data?.spentTodayCents === 7050, `cents=${spendTagged.data?.spentTodayCents}`);
    const retag = await api('POST', `/quests/${tqid}/tracking`, { durationMinutes: 10 });
    check('re-tagging a tagged completion 409s', retag.status === 409);

    const tqUndo = await api('POST', `/quests/${tqid}/uncomplete`);
    check('tracked quest uncompletes', tqUndo.status === 200);
    const statsReverted = await api('GET', '/stats');
    check('undo reverts quest + tag XP (back to 60)', statsReverted.data?.experiencePoints === 60, `xp=${statsReverted.data?.experiencePoints}`);
    const timeAfterUndo = await api('GET', '/time/recent');
    check('undo deletes linked time entry', !(timeAfterUndo.data ?? []).some((e) => e.questId === tqid));
    const spendAfterUndo = await api('GET', '/spending/summary');
    check('undo deletes linked spending', spendAfterUndo.data?.spentTodayCents === 5550, `cents=${spendAfterUndo.data?.spentTodayCents}`);

    // Late tagging: plain completion first, sheet posts afterwards.
    const lq = await api('POST', '/quests', { title: 'E2E Late Tag Quest', difficulty: 1 });
    const lqid = lq.data?.id;
    const untagged = await api('POST', `/quests/${lqid}/tracking`, { durationMinutes: 15 });
    check('tagging an uncompleted quest 409s', untagged.status === 409);
    await api('POST', `/quests/${lqid}/complete`, { fulfillment: 3 });
    const lateTag = await api('POST', `/quests/${lqid}/tracking`, { durationMinutes: 15 });
    check('late tag after completion works', lateTag.status === 201 && lateTag.data?.bonusXp === 5, JSON.stringify(lateTag.data));

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

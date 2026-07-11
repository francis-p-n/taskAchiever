// End-to-end test of the July batch-2 features against a freshly spawned
// server (PORT 3100) and the configured DATABASE_URL.
// Run with: npx tsx scripts/e2e.ts
import 'dotenv/config';
import { spawn, execSync } from 'child_process';

const BASE = 'http://127.0.0.1:3100';
const EMAIL = 'e2e-test@lifeos.local';

let passed = 0;
let failed = 0;

function check(name: string, ok: boolean, detail = '') {
  if (ok) {
    passed++;
    console.log(`  ok  ${name}`);
  } else {
    failed++;
    console.error(`FAIL  ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

async function waitForServer(timeoutMs = 30000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${BASE}/api/health`);
      if (res.ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error('server did not come up');
}

async function main() {
  // A zombie server from an earlier run would answer with stale code while
  // our spawn dies silently on EADDRINUSE — refuse to run in that state.
  try {
    const pre = await fetch(`${BASE}/api/health`, { signal: AbortSignal.timeout(1500) });
    if (pre.ok) {
      throw new Error(
        `a server is already listening on ${BASE} — kill it first ` +
        `(netstat -ano | findstr :3100, then taskkill /PID <pid> /T /F)`
      );
    }
  } catch (err) {
    if ((err as Error).message.includes('already listening')) throw err;
    // connection refused → port is free, proceed
  }

  const server = spawn('npx', ['tsx', 'src/index.ts'], {
    shell: true,
    env: { ...process.env, PORT: '3100' },
    stdio: 'ignore',
  });

  try {
    await waitForServer();
    console.log('server up, running e2e checks\n');

    // --- error handling -----------------------------------------------------
    const notFound = await fetch(`${BASE}/api/nope`);
    check('unknown route → 404 envelope', notFound.status === 404 &&
      (await notFound.json()).error === 'NOT_FOUND');

    const unauthorized = await fetch(`${BASE}/api/quests`);
    check('missing token → 401', unauthorized.status === 401);

    // --- input validation ---------------------------------------------------
    const badBody = await fetch(`${BASE}/api/auth/dev`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    check('missing email → 400 VALIDATION', badBody.status === 400 &&
      (await badBody.json()).error === 'VALIDATION');

    // --- auth ---------------------------------------------------------------
    const login = await fetch(`${BASE}/api/auth/dev`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: EMAIL }),
    });
    const { token } = (await login.json()) as { token: string };
    check('dev login issues JWT', login.status === 200 && Boolean(token));
    const auth = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

    // --- CSRF ---------------------------------------------------------------
    const crossOrigin = await fetch(`${BASE}/api/quests`, {
      method: 'POST',
      headers: { ...auth, Origin: 'https://evil.example' },
      body: JSON.stringify({ title: 'csrf probe' }),
    });
    check('cross-origin write → 403 CSRF', crossOrigin.status === 403);

    // --- quest lifecycle ----------------------------------------------------
    const qid = `e2e-${Date.now()}`;
    const created = await fetch(`${BASE}/api/quests`, {
      method: 'POST',
      headers: auth,
      body: JSON.stringify({ id: qid, title: 'E2E test quest', difficulty: 2 }),
    });
    check('create quest', created.status === 201);

    const badDifficulty = await fetch(`${BASE}/api/quests/${qid}`, {
      method: 'PATCH',
      headers: auth,
      body: JSON.stringify({ difficulty: 9 }),
    });
    check('difficulty 9 rejected by schema', badDifficulty.status === 400);

    const patched = await fetch(`${BASE}/api/quests/${qid}`, {
      method: 'PATCH',
      headers: auth,
      body: JSON.stringify({ difficulty: 4 }),
    });
    check('difficulty amendable via PATCH', patched.status === 200 &&
      ((await patched.json()) as any).difficulty === 4);

    // AI steps (heuristic fallback works without ANTHROPIC_API_KEY)
    const steps = await fetch(`${BASE}/api/quests/${qid}/generate-steps`, {
      method: 'POST',
      headers: auth,
    });
    const stepsBody = (await steps.json()) as any;
    check('generate-steps returns steps', steps.status === 200 &&
      stepsBody.quest.steps.length > 0, JSON.stringify(stepsBody).slice(0, 120));

    // complete → streak
    const completed = await fetch(`${BASE}/api/quests/${qid}/complete`, {
      method: 'POST',
      headers: auth,
      body: JSON.stringify({ fulfillment: 5 }),
    });
    check('complete quest', completed.status === 200);

    const stats = (await (await fetch(`${BASE}/api/stats`, { headers: auth })).json()) as any;
    check('streak tracked and not at risk after completing today',
      stats.currentStreak >= 1 && stats.streakAtRisk === false,
      JSON.stringify(stats));

    // archive / unarchive / visibility
    const archived = await fetch(`${BASE}/api/quests/${qid}/archive`, {
      method: 'POST', headers: auth,
    });
    check('archive quest', archived.status === 200);

    const active = (await (await fetch(`${BASE}/api/quests`, { headers: auth })).json()) as any[];
    check('archived quest hidden from active list', !active.some((q) => q.id === qid));

    const all = (await (await fetch(`${BASE}/api/quests?includeArchived=true`, { headers: auth })).json()) as any[];
    check('archived quest present with includeArchived', all.some((q) => q.id === qid));

    // --- offline sync push + conflict resolution ----------------------------
    const q2 = `e2e-sync-${Date.now()}`;
    await fetch(`${BASE}/api/quests`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({ id: q2, title: 'E2E offline quest' }),
    });
    const syncPush = await fetch(`${BASE}/api/sync/push`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({
        operations: [
          { collection: 'quests', action: 'complete', data: { id: q2, at: new Date().toISOString(), fulfillment: 3 } },
          // upsert with a stale timestamp must lose to the server row
          { collection: 'quests', action: 'upsert', data: { id: q2, at: '2020-01-01T00:00:00Z', title: 'stale title' } },
        ],
      }),
    });
    const syncBody = (await syncPush.json()) as any;
    check('offline complete op applied', syncPush.status === 200 &&
      syncBody.results[0]?.status === 'applied', JSON.stringify(syncBody).slice(0, 200));
    check('stale offline upsert → conflict (server wins)',
      syncBody.results[1]?.status === 'conflict');

    // --- summaries ----------------------------------------------------------
    const weekly = (await (await fetch(`${BASE}/api/summary/weekly`, { headers: auth })).json()) as any;
    check('weekly summary counts completions', weekly.quests?.completed >= 2 &&
      typeof weekly.fitness?.workouts === 'number', JSON.stringify(weekly).slice(0, 160));

    const trends = (await (await fetch(`${BASE}/api/summary/trends?weeks=2`, { headers: auth })).json()) as any;
    check('trends returns per-week series', Array.isArray(trends.weeks) && trends.weeks.length === 2);

    // --- export -------------------------------------------------------------
    const exportJson = (await (await fetch(`${BASE}/api/export`, { headers: auth })).json()) as any;
    check('JSON export has all datasets',
      ['quests', 'questSteps', 'activities', 'nutritionLogs', 'transactions'].every((k) => Array.isArray(exportJson[k])));

    const exportCsv = await fetch(`${BASE}/api/export?format=csv&dataset=quests`, { headers: auth });
    const csvText = await exportCsv.text();
    check('CSV export has header row',
      exportCsv.headers.get('content-type')?.includes('text/csv') === true && csvText.startsWith('id,'));

    // --- notifications (unconfigured FCM degrades gracefully) ---------------
    const registered = await fetch(`${BASE}/api/notifications/register`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({ token: `e2e-token-${Date.now()}`, platform: 'android' }),
    });
    const regBody = (await registered.json()) as any;
    check('device token registration', registered.status === 200 && regBody.registered === true);

    const pushTest = await fetch(`${BASE}/api/notifications/test`, { method: 'POST', headers: auth });
    const pushBody = (await pushTest.json()) as any;
    check('push test no-ops without FIREBASE_SERVICE_ACCOUNT',
      pushTest.status === 200 && pushBody.sent === 0);

    // --- player profile sync (last write wins) --------------------------------
    const newer = new Date().toISOString();
    const older = new Date(Date.now() - 60_000).toISOString();
    const putProfile = (await (await fetch(`${BASE}/api/player/profile`, {
      method: 'PUT', headers: auth,
      body: JSON.stringify({ profile: { name: 'E2E', level: 3 }, updatedAt: newer }),
    })).json()) as any;
    check('profile write accepted', putProfile.accepted === true);

    const staleWrite = (await (await fetch(`${BASE}/api/player/profile`, {
      method: 'PUT', headers: auth,
      body: JSON.stringify({ profile: { name: 'Stale' }, updatedAt: older }),
    })).json()) as any;
    check('stale profile write loses, server copy returned',
      staleWrite.accepted === false && staleWrite.profile?.name === 'E2E');

    const gotProfile = (await (await fetch(`${BASE}/api/player/profile`, { headers: auth })).json()) as any;
    check('profile readback', gotProfile.profile?.name === 'E2E' && gotProfile.updatedAt === newer);

    // --- sidequest suggestions (heuristic fallback without AI key) -----------
    const suggest = (await (await fetch(`${BASE}/api/ai/suggest-quests`, {
      method: 'POST', headers: auth, body: JSON.stringify({ focus: 'Physical' }),
    })).json()) as any;
    check('suggest-quests returns 5 ideas',
      Array.isArray(suggest.suggestions) && suggest.suggestions.length === 5 &&
      suggest.suggestions.every((s: any) => s.title && s.difficulty >= 1),
      JSON.stringify(suggest).slice(0, 160));

    // --- wallet CSV import ----------------------------------------------------
    const run = Date.now();
    const walletCsv =
      'Time,Transaction ID,Description,Amount\n' +
      `"Jul 10, 2026, 3:45:12 PM UTC",tx-${run}-1,Coffee Shop,"$4.50"\n` +
      `"Jul 10, 2026, 4:00:00 PM UTC",tx-${run}-2,Grocery Store,"$23.10"\n` +
      `bad-date,tx-${run}-3,Broken Row,not-money\n`;
    const importRes = await fetch(`${BASE}/api/spending/import`, {
      method: 'POST', headers: auth, body: JSON.stringify({ csv: walletCsv }),
    });
    const importBody = (await importRes.json()) as any;
    check('wallet CSV import inserts parseable rows', importRes.status === 200 &&
      importBody.imported === 2 && importBody.failed === 1, JSON.stringify(importBody));

    const reimport = (await (await fetch(`${BASE}/api/spending/import`, {
      method: 'POST', headers: auth, body: JSON.stringify({ csv: walletCsv }),
    })).json()) as any;
    check('re-importing the same file dedupes', reimport.imported === 0 && reimport.skipped === 2);

    // --- cleanup ------------------------------------------------------------
    for (const id of [qid, q2]) {
      await fetch(`${BASE}/api/quests/${id}`, { method: 'DELETE', headers: auth });
    }
    const afterCleanup = (await (await fetch(`${BASE}/api/quests?includeArchived=true`, { headers: auth })).json()) as any[];
    check('hard delete removes quests', !afterCleanup.some((q) => q.id === qid || q.id === q2));

    // --- rate limiting (last: floods the login route) ------------------------
    let limited = false;
    for (let i = 0; i < 12; i++) {
      const res = await fetch(`${BASE}/api/auth/dev`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: EMAIL }),
      });
      if (res.status === 429) {
        limited = (await res.json()).error === 'RATE_LIMITED';
        break;
      }
    }
    check('login rate limit kicks in (10/min)', limited);

    console.log(`\n${passed} passed, ${failed} failed`);
    process.exitCode = failed > 0 ? 1 : 0;
  } finally {
    server.kill();
    // server.pid is the shell wrapper; by the time we tree-kill it the node
    // grandchild is often orphaned and survives, poisoning the next run
    // with a stale server. Kill whatever still owns the port instead.
    try {
      const netstat = execSync('netstat -ano', { encoding: 'utf8' });
      const listener = netstat
        .split('\n')
        .find((line) => line.includes(':3100') && line.includes('LISTENING'));
      const pid = listener?.trim().split(/\s+/).pop();
      if (pid && Number(pid) > 0) {
        execSync(`taskkill /PID ${pid} /T /F`, { stdio: 'ignore' });
      }
    } catch {
      // nothing listening — already clean
    }
  }
}

main().catch((err) => {
  console.error('e2e failed to run:', err);
  process.exit(1);
});

import { TodoistService } from '../services/todoist.service';
import { CalendarService } from '../services/calendar.service';
import { runReminderCycle } from './reminders';

const SYNC_INTERVAL_MS = 15 * 60 * 1000; // 15 minutes

let timer: NodeJS.Timeout | null = null;

async function runSyncCycle() {
  try {
    await TodoistService.syncAllUsers();
  } catch (err) {
    console.error('[scheduler] todoist sync cycle failed:', err);
  }
  try {
    await CalendarService.syncAllUsers();
  } catch (err) {
    console.error('[scheduler] calendar sync cycle failed:', err);
  }
  try {
    await runReminderCycle();
  } catch (err) {
    console.error('[scheduler] reminder cycle failed:', err);
  }
  // Plaid is webhook-driven (plus on-demand /api/integrations/plaid/sync);
  // no periodic polling needed here.
}

/** In-process periodic sync — works with zero extra infrastructure
 *  (no Redis/queue required). First cycle runs shortly after boot so a
 *  restarted server catches up quickly. */
export function startScheduler() {
  if (timer) return;
  setTimeout(() => {
    runSyncCycle().catch((err) => console.error('[scheduler] initial cycle failed:', err));
  }, 10_000);
  timer = setInterval(() => {
    runSyncCycle().catch((err) => console.error('[scheduler] cycle failed:', err));
  }, SYNC_INTERVAL_MS);
  timer.unref(); // don't keep the process alive just for the scheduler
}

export function stopScheduler() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

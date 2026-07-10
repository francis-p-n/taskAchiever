import { initializeApp, cert, App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import { deviceTokens } from '../db/schema';

// FCM is optional infrastructure, like Redis: without FIREBASE_SERVICE_ACCOUNT
// (inline JSON or a path to the service-account file) every send is a no-op.
let app: App | null = null;
let initFailed = false;

function getApp(): App | null {
  if (app) return app;
  if (initFailed) return null;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return null;
  try {
    const creds = raw.trim().startsWith('{')
      ? JSON.parse(raw)
      : JSON.parse(require('fs').readFileSync(raw.trim(), 'utf8'));
    app = initializeApp({ credential: cert(creds) });
    return app;
  } catch (err) {
    initFailed = true;
    console.error('[push] Firebase init failed — push notifications disabled:', (err as Error).message);
    return null;
  }
}

export const pushConfigured = () => Boolean(process.env.FIREBASE_SERVICE_ACCOUNT) && !initFailed;

/** Sends to every device the user has registered. Dead registration tokens
 *  are pruned as FCM reports them. Returns the number of successful sends. */
export async function sendToUser(
  userId: number,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<number> {
  const firebaseApp = getApp();
  if (!firebaseApp) return 0;
  const messaging = getMessaging(firebaseApp);

  const tokens = await db.query.deviceTokens.findMany({
    where: eq(deviceTokens.userId, userId),
  });
  if (tokens.length === 0) return 0;

  const res = await messaging.sendEachForMulticast({
    tokens: tokens.map((t) => t.token),
    notification: { title, body },
    data,
  });

  const dead = res.responses
    .map((r, i) =>
      !r.success &&
      ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']
        .includes(r.error?.code || '')
        ? tokens[i].token
        : null
    )
    .filter((t): t is string => t !== null);
  if (dead.length > 0) {
    await db.delete(deviceTokens).where(inArray(deviceTokens.token, dead));
  }

  return res.successCount;
}

import { FastifyInstance } from 'fastify';
import { StravaService } from '../services/strava.service';

/** Public Strava OAuth callback — the browser lands here after the user
 *  authorizes, so it cannot carry the app's JWT header. Identity comes from
 *  the signed `state` token minted by GET /api/integrations/strava/auth-url. */
export default async function stravaRoutes(fastify: FastifyInstance) {
  fastify.get('/api/integrations/strava/callback', async (request, reply) => {
    const { code, state, error } = request.query as {
      code?: string;
      state?: string;
      error?: string;
    };

    const page = (title: string, body: string) =>
      reply.type('text/html').send(
        `<html><body style="font-family:sans-serif;padding:40px;text-align:center">` +
          `<h2>${title}</h2><p>${body}</p></body></html>`
      );

    if (error || !code || !state) {
      return page('Strava connection cancelled', 'You can close this tab and return to lifeOS.');
    }

    let userId: number;
    try {
      const payload = fastify.jwt.verify<{ id: number; purpose: string }>(state);
      if (payload.purpose !== 'strava') throw new Error('wrong purpose');
      userId = payload.id;
    } catch {
      return page('Link expired', 'Open lifeOS and click Connect Strava again.');
    }

    const ok = await StravaService.connect(userId, code);
    if (!ok) {
      return page('Strava connection failed', 'Token exchange failed — try again from lifeOS.');
    }

    // Pull activities right away so the app has data on first refresh.
    StravaService.syncUser(userId).catch(() => {});
    return page('Strava connected ✓', 'You can close this tab and return to lifeOS.');
  });
}

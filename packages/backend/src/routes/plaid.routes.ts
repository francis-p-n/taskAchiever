import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { PlaidService } from '../services/plaid.service';

const NOT_CONFIGURED = {
  error: 'Plaid not configured — set PLAID_CLIENT_ID and PLAID_SECRET in packages/backend/.env',
};

export default async function plaidRoutes(fastify: FastifyInstance) {
  // Generate a Link token for the client to open Plaid Link.
  fastify.post('/api/plaid/create-link-token', { preHandler: authenticate }, async (request, reply) => {
    const user = request.user as { id: number };
    if (!PlaidService.configured()) return reply.status(503).send(NOT_CONFIGURED);

    try {
      return reply.send(await PlaidService.createLinkToken(user.id));
    } catch (err: any) {
      return reply.status(502).send({ error: err?.message || 'Plaid link token creation failed' });
    }
  });

  // Exchange the public token from Link, store credentials, run first sync.
  fastify.post('/api/plaid/exchange-public-token', { preHandler: authenticate }, async (request, reply) => {
    const user = request.user as { id: number };
    const { publicToken } = request.body as { publicToken?: string };
    if (!publicToken) return reply.status(400).send({ error: 'publicToken is required' });
    if (!PlaidService.configured()) return reply.status(503).send(NOT_CONFIGURED);

    try {
      await PlaidService.exchangePublicToken(user.id, publicToken);
      const sync = await PlaidService.syncTransactions(user.id);
      return reply.send({ success: true, sync });
    } catch (err: any) {
      return reply.status(502).send({ error: err?.message || 'Plaid token exchange failed' });
    }
  });

  // Plaid webhook (public — Plaid calls this). Ack immediately, sync async.
  fastify.post('/api/plaid/webhook', async (request, reply) => {
    const payload = request.body as any;
    const code = payload?.webhook_code;
    if (
      payload?.webhook_type === 'TRANSACTIONS' &&
      (code === 'SYNC_UPDATES_AVAILABLE' || code === 'DEFAULT_UPDATE') &&
      payload?.item_id
    ) {
      PlaidService.findUserByItemId(payload.item_id)
        .then((userId) => (userId ? PlaidService.syncTransactions(userId) : null))
        .catch((err) => fastify.log.error({ err }, 'Plaid webhook sync failed'));
    }
    return reply.status(200).send({ received: true });
  });
}

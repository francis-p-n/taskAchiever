import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';

export default async function plaidRoutes(fastify: FastifyInstance) {
  // Generate link token for Flutter app
  fastify.post('/api/plaid/create-link-token', { preHandler: authenticate }, async (request, reply) => {
    const user = request.user as { id: number };
    // Call Plaid API to generate link token for this user
    return reply.send({ link_token: 'link-sandbox-123456' });
  });

  // Exchange public token and start initial sync job
  fastify.post('/api/plaid/exchange-public-token', { preHandler: authenticate }, async (request, reply) => {
    const { publicToken } = request.body as { publicToken: string };
    // Call Plaid API to exchange for access_token, encrypt it, save to DB
    // Enqueue 'plaid-sync' job in BullMQ
    return reply.send({ success: true });
  });

  // Plaid Webhook handler
  fastify.post('/api/plaid/webhook', async (request, reply) => {
    const payload = request.body as any;
    if (payload.webhook_type === 'TRANSACTIONS' && payload.webhook_code === 'SYNC_UPDATES_AVAILABLE') {
      // Enqueue 'plaid-sync' job for the associated item_id
      console.log(`Webhook received for item ${payload.item_id}, queuing sync...`);
    }
    return reply.status(200).send();
  });
}

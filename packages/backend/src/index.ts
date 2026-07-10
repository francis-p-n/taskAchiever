import 'dotenv/config';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';

import authRoutes from './routes/auth.routes';
import questRoutes from './routes/quest.routes';

const fastify = Fastify({ logger: true });

// Tolerate empty JSON bodies: clients (e.g. the app's Dio instance) send
// Content-Type: application/json even on body-less POSTs like /sync triggers,
// which Fastify's default parser rejects with FST_ERR_CTP_EMPTY_JSON_BODY.
fastify.addContentTypeParser('application/json', { parseAs: 'string' }, (req, body, done) => {
  if (!body || (typeof body === 'string' && body.trim() === '')) {
    return done(null, {});
  }
  try {
    done(null, JSON.parse(body as string));
  } catch (err) {
    done(err as Error, undefined);
  }
});

// Register plugins
fastify.register(cors, { origin: true });
fastify.register(jwt, { secret: process.env.JWT_SECRET || 'supersecret_life_achiever_key' });

// Register API Routes
fastify.register(authRoutes);
fastify.register(questRoutes);
fastify.register(require('./routes/sync.routes').default);
fastify.register(require('./routes/fitness.routes').default);
fastify.register(require('./routes/food.routes').default);
fastify.register(require('./routes/spending.routes').default);
fastify.register(require('./routes/schedule.routes').default);
fastify.register(require('./routes/plaid.routes').default);
fastify.register(require('./routes/ai.routes').default);
fastify.register(require('./routes/integrations.routes').default);
fastify.register(require('./routes/strava.routes').default);

// Health check route
fastify.get('/api/health', async (request, reply) => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

const start = async () => {
  try {
    await fastify.listen({ port: Number(process.env.PORT) || 3000, host: '0.0.0.0' });
    fastify.log.info(`Server listening on ${fastify.server.address()}`);
    require('./jobs/scheduler').startScheduler();
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();

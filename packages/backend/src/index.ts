import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';

import authRoutes from './routes/auth.routes';
import questRoutes from './routes/quest.routes';

const fastify = Fastify({ logger: true });

// Register plugins
fastify.register(cors, { origin: true });
fastify.register(jwt, { secret: process.env.JWT_SECRET || 'supersecret_life_achiever_key' });

// Register API Routes
fastify.register(authRoutes);
fastify.register(questRoutes);
fastify.register(require('./routes/sync.routes').default);
fastify.register(require('./routes/fitness.routes').default);
fastify.register(require('./routes/plaid.routes').default);
fastify.register(require('./routes/ai.routes').default);

// Health check route
fastify.get('/api/health', async (request, reply) => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

const start = async () => {
  try {
    await fastify.listen({ port: Number(process.env.PORT) || 3000, host: '0.0.0.0' });
    fastify.log.info(`Server listening on ${fastify.server.address()}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();

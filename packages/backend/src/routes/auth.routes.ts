import { FastifyInstance } from 'fastify';
import { db } from '../db';
import { users } from '../db/schema';
import { eq } from 'drizzle-orm';

import { cache } from '../lib/redis';

export default async function authRoutes(fastify: FastifyInstance) {
  // Dev/local login for the single-user desktop app: no Google verification,
  // no Redis session — find-or-create the user and hand back a long-lived JWT.
  fastify.post('/api/auth/dev', {
    config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
    schema: {
      body: {
        type: 'object',
        properties: {
          email: { type: 'string', format: 'email', maxLength: 254 },
          name: { type: 'string', maxLength: 200 },
          accessCode: { type: 'string', maxLength: 200 },
        },
        required: ['email'],
      },
    },
  }, async (request, reply) => {
    const { email, name, accessCode } = request.body as {
      email: string;
      name?: string;
      accessCode?: string;
    };

    // On a publicly reachable deployment AUTH_ACCESS_CODE is mandatory
    // (enforced at boot): this endpoint would otherwise hand out a token
    // for any email to anyone who finds the URL.
    const requiredCode = process.env.AUTH_ACCESS_CODE;
    if (requiredCode && accessCode !== requiredCode) {
      return reply.status(401).send({
        error: 'ACCESS_CODE',
        message: 'Invalid or missing access code',
        statusCode: 401,
      });
    }

    let user = await db.query.users.findFirst({ where: eq(users.email, email) });

    if (!user) {
      const [newUser] = await db.insert(users).values({ email, name: name || email.split('@')[0] }).returning();
      user = newUser;
      const schema = require('../db/schema');
      await db.insert(schema.userStats).values({ userId: user.id });
      await db.insert(schema.userSettings).values({ userId: user.id });
    }

    const token = fastify.jwt.sign({ id: user.id, email: user.email }, { expiresIn: '30d' });
    return reply.send({ token, user });
  });

  fastify.post('/auth/google', {
    config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
  }, async (request, reply) => {
    const { idToken, email, name, googleId } = request.body as { idToken: string, email: string, name: string, googleId: string };
    
    // In production, we should verify the idToken using google-auth-library here.
    // For now, we assume the token is verified and handle the user.
    
    let user = await db.query.users.findFirst({
      where: eq(users.email, email)
    });

    if (!user) {
      const [newUser] = await db.insert(users).values({
        email,
        name,
        googleId
      }).returning();
      user = newUser;
      
      // Initialize stats & settings for new users
      await db.insert(require('../db/schema').userStats).values({ userId: user.id });
      await db.insert(require('../db/schema').userSettings).values({ userId: user.id });
    }

    // Generate JWT
    const token = fastify.jwt.sign({ id: user.id, email: user.email }, { expiresIn: '15m' });
    const refreshToken = fastify.jwt.sign({ id: user.id, type: 'refresh' }, { expiresIn: '7d' });

    // Store session in Redis
    await cache.setEx(`session:${user.id}`, refreshToken, 60 * 60 * 24 * 7);

    return reply.send({ token, refreshToken, user });
  });

  fastify.post('/auth/refresh', async (request, reply) => {
    const { refreshToken } = request.body as { refreshToken: string };
    try {
      const decoded = fastify.jwt.verify<{id: number, type: string}>(refreshToken);
      if (decoded.type !== 'refresh') throw new Error('Invalid token type');

      const storedToken = await cache.get(`session:${decoded.id}`);
      if (storedToken !== refreshToken) throw new Error('Token revoked or expired');

      const user = await db.query.users.findFirst({ where: eq(users.id, decoded.id) });
      if (!user) throw new Error('User not found');

      const newToken = fastify.jwt.sign({ id: user.id, email: user.email }, { expiresIn: '15m' });
      return reply.send({ token: newToken });
    } catch (err) {
      return reply.status(401).send({ error: 'Unauthorized', message: 'Invalid refresh token' });
    }
  });

  fastify.post('/auth/logout', async (request, reply) => {
    try {
      await request.jwtVerify();
      const decoded = request.user as { id: number };
      await cache.del(`session:${decoded.id}`);
      return reply.send({ success: true });
    } catch (err) {
      return reply.status(401).send({ error: 'Unauthorized' });
    }
  });
}

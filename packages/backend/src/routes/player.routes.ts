import { FastifyInstance } from 'fastify';
import { eq } from 'drizzle-orm';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { userSettings } from '../db/schema';

/// Cross-device sync for the client-side player profile (name, class,
/// energies, daily counters). The blob is opaque to the server; conflicts
/// resolve last-write-wins on the client-provided timestamp.
export default async function playerRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/player/profile', async (request, reply) => {
    const user = request.user as { id: number };
    const settings = await db.query.userSettings.findFirst({
      where: eq(userSettings.userId, user.id),
      columns: { playerProfile: true, playerProfileUpdatedAt: true },
    });
    return reply.send({
      profile: settings?.playerProfile ? JSON.parse(settings.playerProfile) : null,
      updatedAt: settings?.playerProfileUpdatedAt?.toISOString() ?? null,
    });
  });

  fastify.put('/api/player/profile', {
    schema: {
      body: {
        type: 'object',
        properties: {
          profile: { type: 'object' },
          updatedAt: { type: 'string' },
        },
        required: ['profile', 'updatedAt'],
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { profile, updatedAt } = request.body as {
      profile: Record<string, unknown>;
      updatedAt: string;
    };

    const incoming = new Date(updatedAt);
    if (Number.isNaN(incoming.getTime())) {
      return reply.status(400).send({
        error: 'VALIDATION',
        message: 'updatedAt must be an ISO timestamp',
        statusCode: 400,
      });
    }

    const settings = await db.query.userSettings.findFirst({
      where: eq(userSettings.userId, user.id),
      columns: { playerProfile: true, playerProfileUpdatedAt: true },
    });

    // Another device wrote a newer profile: the caller loses and should
    // adopt what we return.
    if (settings?.playerProfileUpdatedAt && settings.playerProfileUpdatedAt > incoming) {
      return reply.send({
        accepted: false,
        profile: settings.playerProfile ? JSON.parse(settings.playerProfile) : null,
        updatedAt: settings.playerProfileUpdatedAt.toISOString(),
      });
    }

    await db.update(userSettings)
      .set({
        playerProfile: JSON.stringify(profile),
        playerProfileUpdatedAt: incoming,
        updatedAt: new Date(),
      })
      .where(eq(userSettings.userId, user.id));

    return reply.send({ accepted: true, updatedAt: incoming.toISOString() });
  });
}

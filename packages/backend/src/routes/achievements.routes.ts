import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { AchievementService } from '../services/achievements.service';

export default async function achievementsRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/achievements', async (request, reply) => {
    const user = request.user as { id: number };
    return reply.send(await AchievementService.list(user.id));
  });
}

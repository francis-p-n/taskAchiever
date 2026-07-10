import { FastifyReply, FastifyRequest } from 'fastify';

export async function authenticate(request: FastifyRequest, reply: FastifyReply) {
  try {
    await request.jwtVerify();
    // Single-purpose tokens (e.g. the Strava OAuth `state`) are signed with
    // the same secret but must never work as API auth tokens.
    if ((request.user as { purpose?: string })?.purpose) {
      throw new Error('purpose-scoped token used for auth');
    }
  } catch (err) {
    reply.status(401).send({ error: 'Unauthorized', message: 'Invalid or missing token' });
  }
}

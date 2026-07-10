import { FastifyReply, FastifyRequest } from 'fastify';

const STATE_CHANGING = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

const extraOrigins = new Set(
  (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
);

/** Cross-origin write protection. Auth is bearer-token (no cookies), so
 *  classic CSRF barely applies — this is defence in depth: a browser page
 *  from an unknown origin cannot fire state-changing requests even if a
 *  token ever leaks into cookie/localStorage form. Native clients (Dio,
 *  curl) send no Origin header and pass straight through. */
export async function csrfProtect(request: FastifyRequest, reply: FastifyReply) {
  if (!STATE_CHANGING.has(request.method)) return;
  const origin = request.headers.origin;
  if (!origin) return;

  try {
    if (new URL(origin).host === request.headers.host) return; // same-origin
  } catch {
    // fall through to the allowlist check with the malformed value
  }
  if (extraOrigins.has(origin)) return;

  return reply.status(403).send({
    error: 'CSRF',
    message: 'Cross-origin request rejected',
    statusCode: 403,
  });
}

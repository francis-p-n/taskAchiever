import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';

/** Operational error with a client-safe message and HTTP status. */
export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public code: string = 'ERROR'
  ) {
    super(message);
  }
}

export const notFound = (what = 'Resource') => new AppError(404, `${what} not found`, 'NOT_FOUND');

/** Global handler: every error leaves as { error, message, statusCode }.
 *  Schema-validation failures → 400. AppError → its own status. Anything
 *  else → opaque 500 (internals are logged, never sent to the client). */
export function errorHandler(
  err: FastifyError | AppError,
  request: FastifyRequest,
  reply: FastifyReply
) {
  if (err instanceof AppError) {
    return reply
      .status(err.statusCode)
      .send({ error: err.code, message: err.message, statusCode: err.statusCode });
  }
  const fastifyErr = err as FastifyError;
  if (fastifyErr.validation) {
    return reply
      .status(400)
      .send({ error: 'VALIDATION', message: fastifyErr.message, statusCode: 400 });
  }
  const status = fastifyErr.statusCode || 500;
  if (status >= 500) {
    request.log.error(err);
    return reply
      .status(status)
      .send({ error: 'INTERNAL', message: 'Something went wrong', statusCode: status });
  }
  return reply
    .status(status)
    .send({ error: fastifyErr.code || 'ERROR', message: err.message, statusCode: status });
}

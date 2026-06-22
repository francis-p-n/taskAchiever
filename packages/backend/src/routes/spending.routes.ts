import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { transactions } from '../db/schema';
import { eq, desc } from 'drizzle-orm';

export default async function spendingRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/spending/recent', async (request, reply) => {
    const user = request.user as { id: number };

    const recentTransactions = await db.query.transactions.findMany({
      where: eq(transactions.userId, user.id),
      orderBy: [desc(transactions.transactionDate)],
      limit: 10,
    });

    return reply.send(recentTransactions);
  });

  fastify.post('/api/spending', async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as any;

    const [transaction] = await db.insert(transactions).values({
      userId: user.id,
      amount: data.amount,
      category: data.category,
      merchant: data.merchant,
      transactionDate: new Date(data.transactionDate || new Date()),
    }).returning();

    return reply.status(201).send(transaction);
  });
}

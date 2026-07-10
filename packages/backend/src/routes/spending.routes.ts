import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { transactions } from '../db/schema';
import { eq, desc, and, gte, sql } from 'drizzle-orm';

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

  // Aggregates for the Gold screen: today / this month / per-category breakdown.
  fastify.get('/api/spending/summary', async (request, reply) => {
    const user = request.user as { id: number };

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [todayRow] = await db
      .select({ cents: sql<string>`coalesce(sum(${transactions.amount}), 0)` })
      .from(transactions)
      .where(and(eq(transactions.userId, user.id), gte(transactions.transactionDate, todayStart)));

    const [monthRow] = await db
      .select({ cents: sql<string>`coalesce(sum(${transactions.amount}), 0)` })
      .from(transactions)
      .where(and(eq(transactions.userId, user.id), gte(transactions.transactionDate, monthStart)));

    const byCategory = await db
      .select({
        category: sql<string>`coalesce(${transactions.category}, 'Other')`,
        cents: sql<string>`sum(${transactions.amount})`,
      })
      .from(transactions)
      .where(and(eq(transactions.userId, user.id), gte(transactions.transactionDate, monthStart)))
      .groupBy(sql`coalesce(${transactions.category}, 'Other')`)
      .orderBy(desc(sql`sum(${transactions.amount})`));

    return reply.send({
      spentTodayCents: Number(todayRow?.cents ?? 0),
      spentMonthCents: Number(monthRow?.cents ?? 0),
      byCategory: byCategory.map((r) => ({ category: r.category, cents: Number(r.cents) })),
    });
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

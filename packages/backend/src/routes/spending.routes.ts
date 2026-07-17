import { FastifyInstance } from 'fastify';
import { createHash } from 'crypto';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { transactions } from '../db/schema';
import { eq, desc, and, gte, sql } from 'drizzle-orm';
import { AchievementService } from '../services/achievements.service';

/** Minimal RFC-4180 CSV parse: quoted fields, escaped quotes, CRLF. */
function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      field = '';
      if (row.some((f) => f.trim() !== '')) rows.push(row);
      row = [];
    } else {
      field += c;
    }
  }
  row.push(field);
  if (row.some((f) => f.trim() !== '')) rows.push(row);
  return rows;
}

/** First header index whose name contains any of the needles. */
function findColumn(headers: string[], needles: string[]): number {
  return headers.findIndex((h) =>
    needles.some((needle) => h.toLowerCase().includes(needle))
  );
}

/** "₹1,234.56", "$12.34", "-12,34 €" → signed cents; null when unparseable. */
function parseAmountCents(raw: string): number | null {
  const cleaned = raw.replace(/[^0-9.,-]/g, '');
  if (!cleaned) return null;
  // Treat a trailing ",dd" as a decimal comma (European exports).
  const normalized = /,\d{2}$/.test(cleaned)
    ? cleaned.replace(/\./g, '').replace(',', '.')
    : cleaned.replace(/,/g, '');
  const value = parseFloat(normalized);
  if (!Number.isFinite(value) || value === 0) return null;
  return Math.round(value * 100);
}

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

  // Google Wallet / bank CSV import (Google Takeout "Google Pay" export or
  // any statement with date + amount + description columns). Rows dedupe on
  // the export's transaction id when present, else a content hash — safe to
  // re-import the same file, and Plaid rows are untouched (different ids).
  fastify.post('/api/spending/import', {
    config: { rateLimit: { max: 20, timeWindow: '1 hour' } },
    bodyLimit: 5 * 1024 * 1024,
    schema: {
      body: {
        type: 'object',
        properties: {
          csv: { type: 'string', minLength: 1, maxLength: 4 * 1024 * 1024 },
        },
        required: ['csv'],
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const { csv } = request.body as { csv: string };

    const rows = parseCsv(csv);
    if (rows.length < 2) {
      return reply.status(400).send({ error: 'CSV_EMPTY', message: 'No data rows found', statusCode: 400 });
    }

    const headers = rows[0];
    const dateCol = findColumn(headers, ['time', 'date']);
    const amountCol = findColumn(headers, ['amount']);
    const merchantCol = findColumn(headers, ['description', 'merchant', 'name', 'product']);
    const idCol = findColumn(headers, ['transaction id']);
    const categoryCol = findColumn(headers, ['category']);
    if (dateCol === -1 || amountCol === -1) {
      return reply.status(400).send({
        error: 'CSV_HEADERS',
        message: 'Could not find date and amount columns in the CSV header',
        statusCode: 400,
      });
    }

    let imported = 0;
    let skipped = 0;
    let failed = 0;

    for (const row of rows.slice(1)) {
      const date = new Date(row[dateCol] ?? '');
      const cents = parseAmountCents(row[amountCol] ?? '');
      if (Number.isNaN(date.getTime()) || cents == null) {
        failed++;
        continue;
      }
      const merchant = (merchantCol !== -1 && row[merchantCol]?.trim()) || 'Imported';
      const category = (categoryCol !== -1 && row[categoryCol]?.trim()) || 'Wallet';
      const externalId = idCol !== -1 && row[idCol]?.trim()
        ? `import-${row[idCol].trim()}`
        : `import-${createHash('sha1')
            .update(`${date.toISOString()}|${cents}|${merchant}`)
            .digest('hex')}`;

      const inserted = await db.insert(transactions).values({
        userId: user.id,
        amount: cents,
        category,
        merchant,
        transactionDate: date,
        externalId,
      }).onConflictDoNothing().returning({ id: transactions.id });

      if (inserted.length > 0) imported++;
      else skipped++;
    }

    const newlyUnlocked = imported > 0 ? await AchievementService.evaluate(user.id) : [];
    return reply.send({ imported, skipped, failed, total: rows.length - 1, newlyUnlocked });
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

    const newlyUnlocked = await AchievementService.evaluate(user.id);
    return reply.status(201).send({ ...transaction, newlyUnlocked });
  });
}

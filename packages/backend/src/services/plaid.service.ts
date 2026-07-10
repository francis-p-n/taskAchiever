import { eq, and } from 'drizzle-orm';
import { db } from '../db';
import { userSettings, transactions } from '../db/schema';

export class PlaidService {
  /** True when Plaid credentials are present in the environment. */
  static configured(): boolean {
    return Boolean(process.env.PLAID_CLIENT_ID && process.env.PLAID_SECRET);
  }

  /** POST to the Plaid REST API with credentials injected into the body. */
  private static async post(path: string, body: Record<string, unknown>): Promise<any> {
    const env = process.env.PLAID_ENV || 'sandbox';
    const res = await fetch(`https://${env}.plaid.com${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.PLAID_CLIENT_ID,
        secret: process.env.PLAID_SECRET,
        ...body,
      }),
      signal: AbortSignal.timeout(10000),
    });
    const data: any = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(data?.error_message || `Plaid request to ${path} failed (${res.status})`);
    }
    return data;
  }

  static async createLinkToken(userId: number): Promise<{ link_token: string }> {
    const data = await this.post('/link/token/create', {
      client_name: 'lifeOS',
      user: { client_user_id: String(userId) },
      products: ['transactions'],
      country_codes: ['US'],
      language: 'en',
    });
    return { link_token: data.link_token };
  }

  static async exchangePublicToken(userId: number, publicToken: string): Promise<{ item_id: string }> {
    const data = await this.post('/item/public_token/exchange', { public_token: publicToken });
    await db.insert(userSettings)
      .values({
        userId,
        plaidAccessToken: data.access_token,
        plaidItemId: data.item_id,
        plaidCursor: null,
      })
      .onConflictDoUpdate({
        target: userSettings.userId,
        set: {
          plaidAccessToken: data.access_token,
          plaidItemId: data.item_id,
          plaidCursor: null,
          updatedAt: new Date(),
        },
      });
    return { item_id: data.item_id };
  }

  static async syncTransactions(userId: number): Promise<{
    status: 'success' | 'skipped' | 'error';
    added?: number;
    modified?: number;
    removed?: number;
    reason?: string;
  }> {
    const settings = await db.query.userSettings.findFirst({ where: eq(userSettings.userId, userId) });
    if (!settings || !settings.plaidAccessToken) {
      return { status: 'skipped', reason: 'No Plaid access token' };
    }

    let cursor = settings.plaidCursor;
    let added = 0;
    let modified = 0;
    let removed = 0;

    const fieldsFrom = (tx: any) => ({
      // Plaid amounts are positive for money out — matches the spending UI.
      amount: Math.round(tx.amount * 100),
      category: tx.personal_finance_category?.primary ?? tx.category?.[0] ?? 'Other',
      merchant: tx.merchant_name ?? tx.name ?? 'Unknown',
      transactionDate: new Date(tx.date),
    });

    try {
      let hasMore = true;
      while (hasMore) {
        const body: Record<string, unknown> = {
          access_token: settings.plaidAccessToken,
          count: 500,
        };
        if (cursor) body.cursor = cursor;
        const page = await this.post('/transactions/sync', body);

        for (const tx of page.added ?? []) {
          if (tx.pending) continue;
          await db.insert(transactions)
            .values({ userId, externalId: tx.transaction_id, ...fieldsFrom(tx) })
            .onConflictDoNothing({ target: [transactions.userId, transactions.externalId] });
          added++;
        }

        for (const tx of page.modified ?? []) {
          await db.update(transactions)
            .set(fieldsFrom(tx))
            .where(and(eq(transactions.userId, userId), eq(transactions.externalId, tx.transaction_id)));
          modified++;
        }

        for (const tx of page.removed ?? []) {
          await db.delete(transactions)
            .where(and(eq(transactions.userId, userId), eq(transactions.externalId, tx.transaction_id)));
          removed++;
        }

        cursor = page.next_cursor;
        hasMore = Boolean(page.has_more);
        // Persist the cursor after every page so an interrupted sync resumes instead of re-pulling.
        await db.update(userSettings)
          .set({ plaidCursor: cursor, updatedAt: new Date() })
          .where(eq(userSettings.userId, userId));
      }

      await db.update(userSettings)
        .set({ plaidLastSyncAt: new Date(), updatedAt: new Date() })
        .where(eq(userSettings.userId, userId));

      return { status: 'success', added, modified, removed };
    } catch (err: any) {
      return { status: 'error', reason: err?.message || 'Plaid sync failed' };
    }
  }

  static async findUserByItemId(itemId: string): Promise<number | null> {
    const row = await db.query.userSettings.findFirst({ where: eq(userSettings.plaidItemId, itemId) });
    return row ? row.userId : null;
  }
}

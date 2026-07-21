import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import { db } from '../db';
import { contacts, contactInteractions } from '../db/schema';
import { eq, desc, and } from 'drizzle-orm';

const INTERACTION_TYPES = ['text', 'call', 'meet', 'gift', 'shared-memory'];

// Days without contact before a relationship counts as at-risk, by closeness.
const AT_RISK_DAYS: Record<string, number> = {
  close: 30,
  friend: 60,
  acquaintance: 120,
  professional: 90,
};

/** 0-100: recency against the tier's at-risk window. */
function engagementScore(relationshipType: string | null, lastContactedAt: Date | null): number {
  if (!lastContactedAt) return 0;
  const windowDays = AT_RISK_DAYS[relationshipType ?? 'friend'] ?? 60;
  const daysSince = (Date.now() - lastContactedAt.getTime()) / (24 * 3600 * 1000);
  return Math.max(0, Math.min(100, Math.round(100 * (1 - daysSince / windowDays))));
}

function withScore(contact: typeof contacts.$inferSelect) {
  const score = engagementScore(contact.relationshipType, contact.lastContactedAt);
  return { ...contact, engagementScore: score, atRisk: score === 0 };
}

export default async function relationshipRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/api/contacts', async (request, reply) => {
    const user = request.user as { id: number };
    const rows = await db.query.contacts.findMany({
      where: eq(contacts.userId, user.id),
      orderBy: [desc(contacts.lastContactedAt)],
    });
    return reply.send(rows.map(withScore));
  });

  fastify.post('/api/contacts', {
    schema: {
      body: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string', minLength: 1, maxLength: 255 },
          relationshipType: {
            type: 'string',
            enum: ['close', 'friend', 'acquaintance', 'professional'],
          },
          birthdate: { type: 'string' },
          email: { type: 'string', maxLength: 255 },
          phone: { type: 'string', maxLength: 30 },
          notes: { type: 'string', maxLength: 4000 },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const data = request.body as {
      name: string;
      relationshipType?: string;
      birthdate?: string;
      email?: string;
      phone?: string;
      notes?: string;
    };

    const birthdate = data.birthdate ? new Date(data.birthdate) : null;
    const [contact] = await db.insert(contacts).values({
      userId: user.id,
      name: data.name,
      relationshipType: data.relationshipType ?? 'friend',
      birthdate: birthdate && !Number.isNaN(birthdate.getTime()) ? birthdate : null,
      email: data.email,
      phone: data.phone,
      notes: data.notes,
    }).returning();

    return reply.status(201).send(withScore(contact));
  });

  fastify.delete('/api/contacts/:id', async (request, reply) => {
    const user = request.user as { id: number };
    const id = Number((request.params as { id: string }).id);
    const deleted = await db.delete(contacts)
      .where(and(eq(contacts.id, id), eq(contacts.userId, user.id)))
      .returning({ id: contacts.id });
    if (deleted.length === 0) {
      return reply.status(404).send({
        error: 'NOT_FOUND', message: 'Contact not found', statusCode: 404,
      });
    }
    return reply.send({ deleted: true });
  });

  // Log an interaction; bumps the contact's last_contacted_at.
  fastify.post('/api/contacts/:id/interactions', {
    schema: {
      body: {
        type: 'object',
        required: ['interactionType'],
        properties: {
          interactionType: { type: 'string', enum: INTERACTION_TYPES },
          occurredAt: { type: 'string' },
          notes: { type: 'string', maxLength: 2000 },
          depthScore: { type: 'integer', minimum: 1, maximum: 5 },
        },
      },
    },
  }, async (request, reply) => {
    const user = request.user as { id: number };
    const id = Number((request.params as { id: string }).id);
    const data = request.body as {
      interactionType: string;
      occurredAt?: string;
      notes?: string;
      depthScore?: number;
    };

    const contact = await db.query.contacts.findFirst({
      where: and(eq(contacts.id, id), eq(contacts.userId, user.id)),
    });
    if (!contact) {
      return reply.status(404).send({
        error: 'NOT_FOUND', message: 'Contact not found', statusCode: 404,
      });
    }

    const occurredAt = data.occurredAt ? new Date(data.occurredAt) : new Date();
    if (Number.isNaN(occurredAt.getTime())) {
      return reply.status(400).send({
        error: 'BAD_DATE', message: 'occurredAt is not a valid date', statusCode: 400,
      });
    }

    const [interaction] = await db.insert(contactInteractions).values({
      contactId: id,
      interactionType: data.interactionType,
      occurredAt,
      notes: data.notes,
      depthScore: data.depthScore,
    }).returning();

    // Only advance last_contacted_at — a backdated log must not rewind it.
    if (!contact.lastContactedAt || occurredAt > contact.lastContactedAt) {
      await db.update(contacts)
        .set({ lastContactedAt: occurredAt, updatedAt: new Date() })
        .where(eq(contacts.id, id));
    }

    return reply.status(201).send(interaction);
  });

  fastify.get('/api/contacts/:id/interactions', async (request, reply) => {
    const user = request.user as { id: number };
    const id = Number((request.params as { id: string }).id);
    const contact = await db.query.contacts.findFirst({
      where: and(eq(contacts.id, id), eq(contacts.userId, user.id)),
    });
    if (!contact) {
      return reply.status(404).send({
        error: 'NOT_FOUND', message: 'Contact not found', statusCode: 404,
      });
    }
    const rows = await db.query.contactInteractions.findMany({
      where: eq(contactInteractions.contactId, id),
      orderBy: [desc(contactInteractions.occurredAt)],
      limit: 50,
    });
    return reply.send(rows);
  });

  // Contacts past their tier's contact window, most neglected first.
  fastify.get('/api/contacts/at-risk', async (request, reply) => {
    const user = request.user as { id: number };
    const rows = await db.query.contacts.findMany({
      where: eq(contacts.userId, user.id),
    });
    const atRisk = rows
      .map(withScore)
      .filter((c) => c.atRisk)
      .sort((a, b) => {
        const aTime = a.lastContactedAt?.getTime() ?? 0;
        const bTime = b.lastContactedAt?.getTime() ?? 0;
        return aTime - bTime;
      });
    return reply.send(atRisk);
  });
}

import { FastifyInstance } from 'fastify';
import Anthropic from '@anthropic-ai/sdk';
import { authenticate } from '../middleware/auth';

export const aiConfigured = () => Boolean(process.env.ANTHROPIC_API_KEY);

let client: Anthropic | null = null;
function getClient(): Anthropic {
  client ??= new Anthropic(); // reads ANTHROPIC_API_KEY from env
  return client;
}

/** Offline/unconfigured fallback so quest creation always works. */
const heuristicSteps = (title: string) => [
  `Research ${title}`,
  `Plan ${title}`,
  `Execute ${title}`,
];

const STEPS_SCHEMA = {
  type: 'object' as const,
  properties: {
    steps: {
      type: 'array' as const,
      items: { type: 'string' as const },
      description: '3 to 5 short, actionable steps',
    },
  },
  required: ['steps'],
  additionalProperties: false,
};

export default async function aiRoutes(fastify: FastifyInstance) {
  fastify.post('/api/ai/generate-roadmap', { preHandler: authenticate }, async (request, reply) => {
    const { title } = request.body as { title?: string };
    if (!title || !title.trim()) {
      return reply.status(400).send({ error: 'title is required' });
    }

    if (!aiConfigured()) {
      return reply.send({ steps: heuristicSteps(title), source: 'fallback' });
    }

    try {
      const response = await getClient().messages.create({
        model: 'claude-opus-4-8',
        max_tokens: 1024,
        output_config: { format: { type: 'json_schema', schema: STEPS_SCHEMA } },
        messages: [
          {
            role: 'user',
            content:
              `Break down the quest "${title}" into 3 to 5 concrete, actionable steps ` +
              `a person can check off in a day-planner app. Keep each step under 60 characters.`,
          },
        ],
      });

      if (response.stop_reason === 'refusal' || response.content.length === 0) {
        return reply.send({ steps: heuristicSteps(title), source: 'fallback' });
      }
      const text = response.content.find((b) => b.type === 'text');
      const parsed = text ? (JSON.parse(text.text) as { steps: string[] }) : null;
      if (!parsed?.steps?.length) {
        return reply.send({ steps: heuristicSteps(title), source: 'fallback' });
      }
      return reply.send({ steps: parsed.steps.slice(0, 5), source: 'ai' });
    } catch (err) {
      // Local-first app: never fail quest creation because the AI call failed.
      fastify.log.warn({ err }, 'AI roadmap generation failed, using fallback');
      return reply.send({ steps: heuristicSteps(title), source: 'fallback' });
    }
  });
}

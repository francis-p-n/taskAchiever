import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import fetch from 'node-fetch';

export default async function aiRoutes(fastify: FastifyInstance) {
  fastify.post('/api/ai/generate-roadmap', { preHandler: authenticate }, async (request, reply) => {
    const { title } = request.body as { title: string };
    
    // Call Claude API (Anthropic)
    const prompt = `Break down the quest "${title}" into 3 to 5 actionable steps. Return only a JSON array of strings.`;
    
    // Placeholder implementation for Anthropic API call
    /*
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': process.env.ANTHROPIC_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 300
      })
    });
    */
    
    // Mock response for now
    const steps = [`Research ${title}`, `Plan ${title}`, `Execute ${title}`];
    return reply.send({ steps });
  });
}

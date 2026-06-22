import { Worker } from 'bullmq';
import { TodoistService } from '../services/todoist.service';
import Redis from 'ioredis';

const redisConnection = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
});

export const todoistWorker = new Worker('todoist-sync', async job => {
  const { userId } = job.data;
  console.log(`Processing Todoist sync for user ${userId}`);
  return await TodoistService.syncUser(userId);
}, { connection: redisConnection as any });

todoistWorker.on('completed', job => {
  console.log(`Job ${job.id} completed successfully`);
});

todoistWorker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed:`, err);
});

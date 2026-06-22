import { pgTable, serial, text, timestamp, boolean, integer, jsonb } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: text('email').unique().notNull(),
  name: text('name'),
  googleId: text('google_id').unique(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const quests = pgTable('quests', {
  id: text('id').primaryKey(), // using the string ID from electron store
  userId: integer('user_id').references(() => users.id).notNull(),
  title: text('title').notNull(),
  description: text('description'),
  category: text('category'),
  difficulty: integer('difficulty').default(1),
  dueDate: timestamp('due_date'),
  todoistId: text('todoist_id'),
  completedAt: timestamp('completed_at'),
  fulfillment: integer('fulfillment'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const questSteps = pgTable('quest_steps', {
  id: text('id').primaryKey(),
  questId: text('quest_id').references(() => quests.id).notNull(),
  text: text('text').notNull(),
  completed: boolean('completed').default(false),
  todoistId: text('todoist_id'),
  completedAt: timestamp('completed_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const userStats = pgTable('user_stats', {
  userId: integer('user_id').references(() => users.id).primaryKey(),
  totalCompleted: integer('total_completed').default(0),
  currentStreak: integer('current_streak').default(0),
  longestStreak: integer('longest_streak').default(0),
  lastActiveDate: timestamp('last_active_date'),
  experiencePoints: integer('experience_points').default(0),
  streakFreezes: integer('streak_freezes').default(0),
});

export const userSettings = pgTable('user_settings', {
  userId: integer('user_id').references(() => users.id).primaryKey(),
  todoistApiKey: text('todoist_api_key'), // Will be encrypted in prod
  todoistProjectId: text('todoist_project_id'),
  syncEnabled: boolean('sync_enabled').default(true),
  yearlyGoal: integer('yearly_goal').default(52),
});

export const healthMetrics = pgTable('health_metrics', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id).notNull(),
  date: timestamp('date').notNull(),
  steps: integer('steps').default(0),
  caloriesBurned: integer('calories_burned').default(0),
  heartRateMin: integer('heart_rate_min'),
  heartRateMax: integer('heart_rate_max'),
  sleepScore: integer('sleep_score'),
});

export const nutritionLogs = pgTable('nutrition_logs', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id).notNull(),
  mealType: text('meal_type').notNull(), // Breakfast, Lunch, Dinner, Snack
  calories: integer('calories').notNull(),
  protein: integer('protein'),
  carbs: integer('carbs'),
  fats: integer('fats'),
  loggedAt: timestamp('logged_at').defaultNow().notNull(),
});

export const transactions = pgTable('transactions', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id).notNull(),
  amount: integer('amount').notNull(), // Stored in cents
  category: text('category'),
  merchant: text('merchant'),
  transactionDate: timestamp('transaction_date').notNull(),
});

export const scheduleEvents = pgTable('schedule_events', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id).notNull(),
  title: text('title').notNull(),
  startTime: timestamp('start_time').notNull(),
  endTime: timestamp('end_time').notNull(),
  isGoogleEvent: boolean('is_google_event').default(false),
});

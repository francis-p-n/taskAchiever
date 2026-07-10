import { pgTable, serial, text, timestamp, boolean, integer, index, uniqueIndex } from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: text('email').unique().notNull(),
  name: text('name'),
  googleId: text('google_id').unique(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const quests = pgTable('quests', {
  id: text('id').primaryKey(), // client-generated string ID (offline-first)
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  title: text('title').notNull(),
  description: text('description'),
  category: text('category'),
  difficulty: integer('difficulty').default(1),
  dueDate: timestamp('due_date'),
  recurrence: text('recurrence'), // null | 'daily' | 'weekly'
  todoistId: text('todoist_id'),
  todoistSyncedAt: timestamp('todoist_synced_at'), // last state pushed to Todoist
  completedAt: timestamp('completed_at'),
  fulfillment: integer('fulfillment'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  userIdx: index('quests_user_idx').on(t.userId),
  userUpdatedIdx: index('quests_user_updated_idx').on(t.userId, t.updatedAt),
}));

export const questSteps = pgTable('quest_steps', {
  id: text('id').primaryKey(),
  questId: text('quest_id').references(() => quests.id, { onDelete: 'cascade' }).notNull(),
  text: text('text').notNull(),
  completed: boolean('completed').default(false),
  todoistId: text('todoist_id'),
  completedAt: timestamp('completed_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  questIdx: index('quest_steps_quest_idx').on(t.questId),
}));

export const questsRelations = relations(quests, ({ many, one }) => ({
  steps: many(questSteps),
  user: one(users, { fields: [quests.userId], references: [users.id] }),
}));

export const questStepsRelations = relations(questSteps, ({ one }) => ({
  quest: one(quests, { fields: [questSteps.questId], references: [quests.id] }),
}));

export const userStats = pgTable('user_stats', {
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).primaryKey(),
  totalCompleted: integer('total_completed').default(0),
  currentStreak: integer('current_streak').default(0),
  longestStreak: integer('longest_streak').default(0),
  lastActiveDate: timestamp('last_active_date'),
  experiencePoints: integer('experience_points').default(0),
  streakFreezes: integer('streak_freezes').default(0),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const userSettings = pgTable('user_settings', {
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).primaryKey(),
  todoistApiKey: text('todoist_api_key'), // Will be encrypted in prod
  todoistProjectId: text('todoist_project_id'),
  todoistLastSyncAt: timestamp('todoist_last_sync_at'),
  icalUrl: text('ical_url'), // secret iCal address (Google Calendar et al.)
  calendarLastSyncAt: timestamp('calendar_last_sync_at'),
  plaidAccessToken: text('plaid_access_token'), // Will be encrypted in prod
  plaidItemId: text('plaid_item_id'),
  plaidCursor: text('plaid_cursor'), // /transactions/sync incremental cursor
  plaidLastSyncAt: timestamp('plaid_last_sync_at'),
  syncEnabled: boolean('sync_enabled').default(true),
  yearlyGoal: integer('yearly_goal').default(52),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const healthMetrics = pgTable('health_metrics', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  date: timestamp('date').notNull(),
  steps: integer('steps').default(0),
  caloriesBurned: integer('calories_burned').default(0),
  heartRateMin: integer('heart_rate_min'),
  heartRateMax: integer('heart_rate_max'),
  sleepScore: integer('sleep_score'),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  userDateIdx: uniqueIndex('health_metrics_user_date_idx').on(t.userId, t.date),
}));

export const nutritionLogs = pgTable('nutrition_logs', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  mealType: text('meal_type').notNull(), // Breakfast, Lunch, Dinner, Snack
  calories: integer('calories').notNull(),
  protein: integer('protein'),
  carbs: integer('carbs'),
  fats: integer('fats'),
  loggedAt: timestamp('logged_at').defaultNow().notNull(),
}, (t) => ({
  userLoggedIdx: index('nutrition_logs_user_logged_idx').on(t.userId, t.loggedAt),
}));

export const transactions = pgTable('transactions', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  amount: integer('amount').notNull(), // Stored in cents
  category: text('category'),
  merchant: text('merchant'),
  transactionDate: timestamp('transaction_date').notNull(),
  externalId: text('external_id'), // Plaid transaction_id — dedupe key for synced rows
}, (t) => ({
  userDateIdx: index('transactions_user_date_idx').on(t.userId, t.transactionDate),
  userExternalIdx: uniqueIndex('transactions_user_external_idx').on(t.userId, t.externalId),
}));

export const scheduleEvents = pgTable('schedule_events', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  title: text('title').notNull(),
  startTime: timestamp('start_time').notNull(),
  endTime: timestamp('end_time').notNull(),
  isGoogleEvent: boolean('is_google_event').default(false),
  externalId: text('external_id'), // iCal UID (+ occurrence suffix) — dedupe key for synced events
}, (t) => ({
  userStartIdx: index('schedule_events_user_start_idx').on(t.userId, t.startTime),
  userExternalIdx: uniqueIndex('schedule_events_user_external_idx').on(t.userId, t.externalId),
}));

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
  archivedAt: timestamp('archived_at'), // hidden from the active list, kept for history
  trackingBonusXp: integer('tracking_bonus_xp').default(0), // opt-in tag bonus, reverted on undo
  reminderSentAt: timestamp('reminder_sent_at'), // last due-soon push, avoids repeats
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
  stravaAthleteId: text('strava_athlete_id'),
  stravaAccessToken: text('strava_access_token'), // Will be encrypted in prod
  stravaRefreshToken: text('strava_refresh_token'),
  stravaExpiresAt: timestamp('strava_expires_at'),
  stravaLastSyncAt: timestamp('strava_last_sync_at'),
  syncEnabled: boolean('sync_enabled').default(true),
  yearlyGoal: integer('yearly_goal').default(52),
  remindersEnabled: boolean('reminders_enabled').default(true),
  // Client player profile (name/class/energies/daily counters) as an opaque
  // JSON blob — the server only arbitrates last-write-wins between devices.
  playerProfile: text('player_profile'),
  playerProfileUpdatedAt: timestamp('player_profile_updated_at'),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

// FCM registration tokens; one row per installed app instance.
export const deviceTokens = pgTable('device_tokens', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  token: text('token').notNull(),
  platform: text('platform'), // 'android' | 'ios' | 'web'
  createdAt: timestamp('created_at').defaultNow().notNull(),
  lastSeenAt: timestamp('last_seen_at').defaultNow().notNull(),
}, (t) => ({
  tokenIdx: uniqueIndex('device_tokens_token_idx').on(t.token),
  userIdx: index('device_tokens_user_idx').on(t.userId),
}));

export const healthMetrics = pgTable('health_metrics', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  date: timestamp('date').notNull(),
  steps: integer('steps').default(0),
  caloriesBurned: integer('calories_burned').default(0),
  heartRateMin: integer('heart_rate_min'),
  heartRateMax: integer('heart_rate_max'),
  sleepScore: integer('sleep_score'),
  sleepMinutes: integer('sleep_minutes'), // last night's sleep, from Health Connect
  hrvRmssd: integer('hrv_rmssd'), // recovery/stress proxy (higher = calmer)
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  userDateIdx: uniqueIndex('health_metrics_user_date_idx').on(t.userId, t.date),
}));

// Individual workouts/activities from any source. Strava rows carry the
// Strava id as external_id; overlapping duplicates from other sources are
// removed on import (Strava wins).
export const activities = pgTable('activities', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  source: text('source').notNull(), // 'strava' | 'manual' | 'health'
  externalId: text('external_id'),
  name: text('name').notNull(),
  sportType: text('sport_type'),
  startTime: timestamp('start_time').notNull(),
  durationSeconds: integer('duration_seconds').default(0),
  distanceMeters: integer('distance_meters'),
  caloriesBurned: integer('calories_burned').default(0),
  avgHeartRate: integer('avg_heart_rate'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (t) => ({
  userStartIdx: index('activities_user_start_idx').on(t.userId, t.startTime),
  userExternalIdx: uniqueIndex('activities_user_external_idx').on(t.userId, t.source, t.externalId),
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
  questId: text('quest_id'), // set when tagged from a quest completion
}, (t) => ({
  userDateIdx: index('transactions_user_date_idx').on(t.userId, t.transactionDate),
  userExternalIdx: uniqueIndex('transactions_user_external_idx').on(t.userId, t.externalId),
  questIdx: index('transactions_quest_idx').on(t.questId),
}));

// Unlock state for the achievement catalog (defined in code, see
// achievements.service.ts). One row per unlock; the catalog itself is not
// stored here.
export const userAchievements = pgTable('user_achievements', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  key: text('key').notNull(),
  unlockedAt: timestamp('unlocked_at').defaultNow().notNull(),
}, (t) => ({
  userKeyIdx: uniqueIndex('user_achievements_user_key_idx').on(t.userId, t.key),
}));

// 24/7 time tracking (lifeOS v2): one row per logged block of time.
export const timeEntries = pgTable('time_entries', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  category: text('category').notNull(), // 'quest' | 'work' | 'health' | 'social' | 'rest' | 'waste'
  startTime: timestamp('start_time').notNull(),
  durationMinutes: integer('duration_minutes').notNull(),
  notes: text('notes'),
  moodBefore: integer('mood_before'), // 1-10
  energyBefore: integer('energy_before'), // 1-10
  moodAfter: integer('mood_after'),
  energyAfter: integer('energy_after'),
  roiScore: integer('roi_score'), // 0-100, computed server-side
  questId: text('quest_id'), // set when tagged from a quest completion
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  userStartIdx: index('time_entries_user_start_idx').on(t.userId, t.startTime),
  questIdx: index('time_entries_quest_idx').on(t.questId),
}));

// Morning/evening wellness check-in; one row per user per calendar day.
export const dailyCheckins = pgTable('daily_checkins', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  date: timestamp('date').notNull(), // midnight of the local day
  morningMood: integer('morning_mood'), // 1-10
  morningEnergy: integer('morning_energy'),
  morningStress: integer('morning_stress'),
  sleepMinutes: integer('sleep_minutes'),
  eveningMood: integer('evening_mood'),
  eveningEnergy: integer('evening_energy'),
  eveningStress: integer('evening_stress'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  userDateIdx: uniqueIndex('daily_checkins_user_date_idx').on(t.userId, t.date),
}));

// Relationship tracking: people the user wants to stay intentional about.
export const contacts = pgTable('contacts', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  name: text('name').notNull(),
  relationshipType: text('relationship_type').default('friend'), // 'close' | 'friend' | 'acquaintance' | 'professional'
  birthdate: timestamp('birthdate'),
  email: text('email'),
  phone: text('phone'),
  tags: text('tags'), // JSON array as text
  notes: text('notes'),
  lastContactedAt: timestamp('last_contacted_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  userIdx: index('contacts_user_idx').on(t.userId),
}));

export const contactInteractions = pgTable('contact_interactions', {
  id: serial('id').primaryKey(),
  contactId: integer('contact_id').references(() => contacts.id, { onDelete: 'cascade' }).notNull(),
  interactionType: text('interaction_type').notNull(), // 'text' | 'call' | 'meet' | 'gift' | 'shared-memory'
  occurredAt: timestamp('occurred_at').notNull(),
  notes: text('notes'),
  depthScore: integer('depth_score'), // 1-5
  questId: text('quest_id'), // set when tagged from a quest completion
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (t) => ({
  contactIdx: index('contact_interactions_contact_idx').on(t.contactId, t.occurredAt),
  questIdx: index('contact_interactions_quest_idx').on(t.questId),
}));

// Atomic habits with streak state kept denormalized on the habit row —
// completions are the audit log, the streak columns are the fast path.
export const habits = pgTable('habits', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  name: text('name').notNull(),
  category: text('category').default('fitness'), // 'fitness' | 'learning' | 'spirituality' | 'social' | 'other'
  difficulty: integer('difficulty').default(3), // 1-5, scales XP
  targetFrequency: text('target_frequency').default('daily'), // 'daily' | '3x-weekly' | 'weekly'
  currentStreakDays: integer('current_streak_days').default(0),
  longestStreakDays: integer('longest_streak_days').default(0),
  lastCompletedAt: timestamp('last_completed_at'),
  freezesRemaining: integer('freezes_remaining').default(2), // refills monthly
  active: boolean('active').default(true),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (t) => ({
  userIdx: index('habits_user_idx').on(t.userId),
}));

export const habitCompletions = pgTable('habit_completions', {
  id: serial('id').primaryKey(),
  habitId: integer('habit_id').references(() => habits.id, { onDelete: 'cascade' }).notNull(),
  completedAt: timestamp('completed_at').notNull(),
  notes: text('notes'),
  streakDay: integer('streak_day'), // day N of the streak at completion time
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (t) => ({
  habitIdx: index('habit_completions_habit_idx').on(t.habitId, t.completedAt),
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

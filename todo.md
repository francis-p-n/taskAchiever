# 📋 Project Roadmap & Backlog

This file tracks the completed milestones, active tasks, and planned enhancements for **Life Achiever** (formerly SideQuest Achiever).

---

## 🚀 Milestones

### Completed Architecture Migration (v2.0 Backend)
- [x] **Monorepo Structure:** Segmented apps/flutter and packages/backend.
- [x] **Docker Infrastructure:** Local Postgres 15 and Redis 7 setups.
- [x] **Drizzle Schema:** Established relational schema for Users, Quests, Stats, and Settings.
- [x] **Fastify JWT Auth:** Implemented Google Auth routes with short-lived access tokens and Redis-backed refresh tokens.
- [x] **Quest Service:** Gamification, XP scaling, and streak freezing implemented.
- [x] **Sync API:** Implemented offline-first queue processing (`/api/sync/push`) with Redis locking mechanisms to prevent race conditions.
- [x] **Todoist Background Worker:** Moved Todoist synchronization into a server-side BullMQ worker.

### Legacy V1 Completed Features (Electron)
*See `/legacy` directory for historic implementation of: Custom Window controls, Auto-Categorization engine, SVG heatmaps.*

---

## 🛠️ Active Development / Immediate Backlog

- [ ] **Run pending DB migration:** `cd packages/backend && npx tsx scripts/migrate-2026-07-features.ts` (quest recurrence, Strava columns, activities table).
- [ ] **Strava app credentials:** create an API app at strava.com/settings/api and set `STRAVA_CLIENT_ID` / `STRAVA_CLIENT_SECRET` in `packages/backend/.env`.
- [ ] **Flutter Isar Schema:** Replicate the Drizzle models inside local Isar NoSQL collections for the client.
- [ ] **Dart SyncEngine:** Build the background polling service that drains local Isar queues into the Fastify backend.
- [ ] **Data Migration Script:** Create a CLI script to ingest `sidequest-data.json` from the legacy v1 app into the v2 PostgreSQL database.

### Completed 2026-07-10 (feature batch)
- [x] Completed quests leave the active tabs; Undo on cards and snackbars (XP reverted locally and server-side).
- [x] Recurring quests (daily/weekly) with respawn-on-complete and a New Quest dialog.
- [x] Energy Menu removed; Reset All Energy refills bars to full.
- [x] Settings page (player profile + integrations) and Status page (backend health, stats, integration status).
- [x] Player ID editable from dashboard and Settings.
- [x] Todoist side quests live in the Quests screen; project-by-name import ("Sidequest"); AI-generated actionable steps on imported tasks.
- [x] Dashboard "Up Next" uses real synced calendar events.
- [x] Meal-photo analysis: Claude vision estimates calories/macros into the log-meal form.
- [x] Strava OAuth + activity import with duplicate-workout removal.
- [x] Health Connect route for Nothing X / CMF Watch (Android).

---

## 🔮 Future Phases

### Fitness & Health
- [x] **Health Connect Integration:** Read native CMF watch steps/heart-rate data on Android.
- [x] **Fitness Dashboard:** Visual progress tracking against customizable goals.

### Schedule & Spending
- [x] **Google Calendar Sync:** Two-way sync worker for daily events.
- [x] **Plaid Integration:** Webhook-driven background ingestion of bank transactions.
- [x] **Budget Dashboards:** Monthly spending thresholds and categorizations.

### AI & Suggestions
- [x] **Claude API Service:** Generate roadmap steps dynamically via LLM.
- [x] **Smart Suggestions Engine:** Multi-domain heuristic suggestions (e.g. "You haven't run this week, and the weather is nice.")

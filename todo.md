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

- [ ] **Flutter Isar Schema:** Replicate the Drizzle models inside local Isar NoSQL collections for the client.
- [ ] **Dart SyncEngine:** Build the background polling service that drains local Isar queues into the Fastify backend.
- [ ] **Flutter Quests UI:** Build the gamified task management UI in Flutter using Riverpod.
- [ ] **Data Migration Script:** Create a CLI script to ingest `sidequest-data.json` from the legacy v1 app into the v2 PostgreSQL database.

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

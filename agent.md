# 🤖 Agent Context & Onboarding Guide

Welcome! This file serves as the single source of truth and onboarding context for any AI coding assistant working in this repository.

---

## 🎯 Project Overview & Mission

**Life Achiever** (formerly SideQuest Achiever) is a comprehensive life-management ecosystem designed to gamify and track five major domains: Quests (skill development), Fitness, Food, Spending, and Schedule. It utilizes an offline-first mobile and desktop application that syncs in real-time to a robust backend infrastructure.

---

## 🛠️ Technology Stack

- **Monorepo:** Organized with `apps/` and `packages/`
- **Frontend (Client):** Flutter, Dart, Riverpod, Isar Local DB, go_router
- **Backend (API):** Node.js, Fastify, TypeScript
- **Database (Primary):** PostgreSQL 15, Drizzle ORM
- **Cache & Queues:** Redis 7, BullMQ
- **External Integrations:** Todoist API, Google OAuth, (Future: Health Connect, Plaid)

---

## 📂 Key Files & Directories

- [docker-compose.yml](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/docker-compose.yml): Local development infrastructure (Postgres & Redis).
- **`packages/backend/` (Fastify Server)**
  - [src/index.ts](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/packages/backend/src/index.ts): Fastify application entrypoint.
  - [src/db/schema.ts](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/packages/backend/src/db/schema.ts): Drizzle ORM definitions for Postgres tables.
  - [src/routes/](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/packages/backend/src/routes/): API Endpoints (`auth.routes.ts`, `quest.routes.ts`, `sync.routes.ts`).
  - [src/services/](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/packages/backend/src/services/): Business logic and gamification calculation.
  - [src/jobs/todoist.worker.ts](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/packages/backend/src/jobs/todoist.worker.ts): BullMQ worker handling Todoist REST integration.
- **`apps/flutter/` (Client Application)**
  - `lib/core/`: Networking, SyncEngine, and global utilities.
  - `lib/features/`: Domain-specific UI and State (Quests, Fitness, Food, Spending).
- **`legacy/`**
  - Contains the original `SideQuest Achiever` Electron JS application code for reference and data migration strategies.

---

## ⚡ Active Context & Next Steps

### Current Focus
- The system architecture has just undergone a massive rewrite from local Electron to a Client-Server Flutter/Fastify model.
- Backend infrastructure (Postgres, Redis, Fastify) is scaffolded with Phase 1 (Auth), Phase 2 (Quests), Phase 3 (Todoist), and Phase 4 (Sync) logically implemented.

### Immediate Next Steps
1. Define the Isar local database schemas inside the Flutter app.
2. Build the `SyncEngine` client-side Dart service to communicate with `/api/sync/push`.
3. Construct the Flutter UI for Quests and Gamification.

---

## 📝 Changelog / Recent Edits

### 2026-06-22 (Agent: Antigravity)
- **Massive Architecture Rewrite:** Moved legacy Electron app to `/legacy`.
- Scaffolded Flutter monorepo in `/apps/flutter` and Fastify backend in `/packages/backend`.
- Added `docker-compose.yml` for Postgres and Redis.
- Implemented `Drizzle` schema (`users`, `quests`, `user_stats`).
- Implemented JWT Auth & Redis Session logic.
- Created Backend sync endpoints (`/api/sync/push`) supporting Redis locking.
- Created BullMQ worker for Todoist synchronization.

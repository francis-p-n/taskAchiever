# 🤖 Agent Context & Onboarding Guide

Welcome! This file serves as the single source of truth and onboarding context for any AI coding assistant working in this repository.

---

## 🎯 Project Overview & Mission

**lifeOS** (formerly Life Achiever / SideQuest Achiever; Dart package `life_os`) is a comprehensive life-management ecosystem designed to gamify and track five major domains: Quests (skill development), Fitness, Food, Spending, and Schedule. It utilizes an offline-first mobile and desktop application that syncs in real-time to a robust backend infrastructure.

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
- Backend infrastructure (Postgres, Redis, Fastify) is fully scaffolded across ALL 9 phases, including Auth, Quests, Sync, Todoist, Data Migration, Calendar, Fitness, Spending (Plaid), and AI Generation (Claude).

### Immediate Next Steps
1. Define the remaining Isar local database schemas inside the Flutter app.
2. Construct the Flutter UI for Quests, Fitness, Spending, and Scheduling using Riverpod.
3. Test the end-to-end webhook flows with Plaid Sandbox.

---

## 📝 Changelog / Recent Edits

### 2026-07-10 (Agent: Claude Code)
- **Quest lifecycle:** completions move cards to the Completed tab with an Undo action; new `POST /api/quests/:id/uncomplete` reverts XP server-side; dashboard "Today's Quests" and "Up Next" now use live data.
- **Recurring quests:** `recurrence` column ('daily'/'weekly'); completing spawns the next occurrence; New Quest dialog in the Quests screen.
- **Energy:** removed the Energy Menu board; Reset All Energy refills to max.
- **New pages:** `/settings` (player profile + integration connections) and `/status` (backend health, lifetime stats, integration status), both in the nav.
- **Todoist:** side quests render as real cards; connect accepts a project *name* (e.g. "Sidequest"); imported tasks get AI-generated actionable steps (`quest_steps`).
- **Food:** `POST /api/food/analyze` (Claude vision) estimates calories/macros from a photo; log-meal sheet has a photo button that auto-fills the form.
- **Strava:** OAuth connect (`strava.routes.ts` public callback + signed state), activity import into the new `activities` table, duplicate-workout removal (±45 min window, Strava wins).
- **Health Connect:** Android route for Nothing X / CMF Watch — `health_sync.dart` pushes daily totals (`POST /api/fitness` upsert) and workouts (`POST /api/fitness/activity` with dedupe).
- **⚠️ Pending:** run `npx tsx scripts/migrate-2026-07-features.ts` in `packages/backend` before starting the new backend (adds recurrence/Strava columns and the activities table).

### 2026-06-22 (Agent: Antigravity)
- **Massive Architecture Rewrite:** Moved legacy Electron app to `/legacy`.
- Scaffolded Flutter monorepo in `/apps/flutter` and Fastify backend in `/packages/backend`.
- Added `docker-compose.yml` for Postgres and Redis.
- Implemented `Drizzle` schema (`users`, `quests`, `user_stats`).
- Implemented JWT Auth & Redis Session logic.
- Created Backend sync endpoints (`/api/sync/push`) supporting Redis locking.
- Created BullMQ workers for Todoist and Google Calendar synchronization.
- Created `migration.ts` to seamlessly import legacy v1.0 local JSON data to Postgres.
- Initialized REST endpoints for Plaid webhooks, Health Connect ingestion, and Anthropic LLM roadmap generation.

# 🏛️ System Architecture

**Life Achiever** (formerly SideQuest Achiever) is structured as a client-server architecture consisting of a Flutter frontend applications and a Fastify Node.js backend. It utilizes PostgreSQL as the primary database and Redis for caching, session management, and job queues.

---

## 🗺️ High-Level Component Diagram

```mermaid
graph TD
    subgraph Client Applications
        flutter[Flutter App (Android/iOS/Windows)]
        isar[(Isar Local DB)]
        health[Health Connect / Apple Health]
        sync[SyncEngine]
    end

    subgraph Backend - Fastify API
        api[REST API & WebSockets]
        auth_svc[Auth Service (JWT)]
        quest_svc[Quest Service]
        sync_svc[Sync Service]
        todoist_worker[Todoist BullMQ Worker]
    end

    subgraph Infrastructure
        pg[(PostgreSQL)]
        redis[(Redis Cache & Queues)]
    end

    subgraph External Systems
        todoist[Todoist REST API v1]
        google[Google OAuth / Calendar]
    end

    %% Client internal
    flutter <--> isar
    flutter <--> sync
    flutter <-- read --> health

    %% Client <-> Server
    sync <-->|HTTPS push/pull| api

    %% Backend internal
    api <--> auth_svc
    api <--> quest_svc
    api <--> sync_svc
    
    auth_svc <-->|Sessions/Lock| redis
    quest_svc <-->|Cache| redis
    sync_svc <-->|PubSub/Lock| redis
    
    api <-->|Read/Write| pg
    todoist_worker <-->|Read/Write| pg
    todoist_worker <-->|Job Queue| redis

    %% External
    todoist_worker <-->|HTTPS| todoist
    auth_svc <-->|HTTPS| google
```

---

## 📦 Component Responsibilities

### 1. Backend Server (`packages/backend`)
*   **API Framework:** Fastify provides high-performance routing and HTTP services.
*   **Auth Service:** Uses Google Sign-In with Fastify-JWT. Short-lived Access Tokens (15m) and long-lived Refresh Tokens (7d) stored securely in Redis.
*   **Database ORM:** Drizzle ORM manages strict TypeScript schema definitions mapping to PostgreSQL tables.
*   **Quest Service:** Handles the CRUD of quests, calculation of user statistics, streak freezes, and XP distribution. Heavily caches data into Redis.
*   **Offline Sync Service:** Exposes `/api/sync/push` and `/api/sync/pull` endpoints. Utilizes Redis distributed locks (`SET NX EX`) to safely process batch offline operations.
*   **Background Workers:** Uses BullMQ to manage asynchronous jobs, specifically the `todoist-sync` worker which synchronizes quests with a user's Todoist account securely.

### 2. Frontend Client (`apps/flutter`)
*   **Framework:** Built on Flutter to compile natively to Windows, iOS, and Android from a single codebase.
*   **State Management:** Riverpod provides robust reactive state management and dependency injection.
*   **Routing:** `go_router` handles declarative routing and deep-linking.
*   **Local Storage (Offline-first):** Uses `Isar` NoSQL database for instant local reads and offline queueing. The `SyncEngine` drains the operations queue when connectivity is restored.

---

## 💾 Database Schema (PostgreSQL via Drizzle)

The central source of truth uses relational tables:

*   **`users`**: Google OAuth identity mappings.
*   **`quests` / `quest_steps`**: Core tasks, descriptions, difficulties, and associated step lists.
*   **`user_stats`**: Tracks XP, streaks, longest streaks, total completions, and freezes.
*   **`user_settings`**: Stores configuration and encrypted API keys (e.g. Todoist API key).

*(Future tables will include `fitness_entries`, `meals`, `spending_accounts`, and `calendar_events`)*

---

## 🔄 Synchronization Workflows

### 1. Offline-First Sync Architecture
1. **Local Write:** User actions (e.g., creating a quest) are immediately written to the local Isar database.
2. **Queueing:** The operation is added to a `pending_operations` queue locally.
3. **Push:** When internet connectivity is detected, `SyncEngine` batches operations and POSTs them to `/api/sync/push`.
4. **Server Processing:** Fastify acquires a Redis lock for the user's domain, processes the UPSERTs against Postgres, invalidates caches, and releases the lock.
5. **Pull:** Clients frequently poll `/api/sync/pull?since=TIMESTAMP` to fetch changes made by other devices or background workers.

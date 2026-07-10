# lifeOS

Welcome to **lifeOS**, a comprehensive gamified life-management application that turns your daily routines into rewarding quests. lifeOS tracks and syncs your tasks, fitness, nutrition, spending, and schedule across desktop and mobile.

---

## 🛠️ Technology Stack

lifeOS is built on a modern, offline-first client-server architecture:

- **Frontend**: [Flutter](https://flutter.dev/) (Compiles to Windows, Android, iOS)
- **Local Database**: [Isar](https://isar.dev/) (Offline-first NoSQL)
- **Backend API**: [Fastify](https://fastify.dev/) & Node.js
- **Primary Database**: PostgreSQL (via [Drizzle ORM](https://orm.drizzle.team/))
- **Cache & Jobs**: Redis & [BullMQ](https://docs.bullmq.io/)

---

## 🚀 Quick Start / Development Setup

### Prerequisites
- Node.js (v20+)
- Flutter SDK (v3.19+)
- Docker & Docker Compose

### 1. Start Infrastructure
Boot up the local PostgreSQL database and Redis server using Docker.
```bash
docker-compose up -d
```

### 2. Run the Backend API
Navigate to the backend package, install dependencies, push the database schema, and start the development server.
```bash
cd packages/backend
npm install
npm run db:push
npm run dev
```

### 3. Run the Flutter Client
Open a new terminal, navigate to the Flutter application, install dependencies, and launch the app.
```bash
cd apps/flutter
flutter pub get
flutter run
```

---

## 🏗️ Project Structure

- `/apps/flutter`: The cross-platform client app.
- `/packages/backend`: The Fastify REST API, authentication, and sync service.
- `/legacy`: Contains the legacy v1.0.0 Electron `SideQuest Achiever` application for reference.

---

## 🔒 Environment Configuration

Create a `.env` file in `packages/backend` using the provided example format:

```env
PORT=3000
DATABASE_URL=postgres://life_achiever:password@localhost:5432/life_achiever
REDIS_URL=redis://localhost:6379
JWT_SECRET=super_secret_key

# Optional integrations
ANTHROPIC_API_KEY=sk-ant-...        # AI quest steps + meal-photo analysis
STRAVA_CLIENT_ID=12345              # strava.com/settings/api
STRAVA_CLIENT_SECRET=...
```

## ⌚ Wearables: Nothing X / CMF Watch

Nothing X has no public API, so watch data routes through **Google Health
Connect** on the phone:

1. In the Nothing X (or CMF Watch) app, enable **Sync with Health Connect**.
2. In Health Connect, grant lifeOS read access to steps, heart rate, active
   energy and exercise.
3. In lifeOS (Android build) → Fitness → **Sync Health Connect**.

Steps/calories/heart-rate land in the daily metrics; workouts are logged as
activities. Workouts already imported from Strava are detected by their start
time and skipped, so the same session is never counted twice.

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

## 🌐 Production Deployment (PC + phone)

The backend is a stateless container against Neon Postgres — host it anywhere
and every device shares one account (quests, XP, streaks, meals, spending and
the player profile all sync; offline mutations replay with last-write-wins).

### 1. Deploy the backend (Render, free tier)

1. Push this repo to GitHub (already done if you're reading this there).
2. On [render.com](https://render.com): **New + → Blueprint** → select the
   repo. Render reads `render.yaml` and builds `packages/backend/Dockerfile`.
3. Fill in the prompted env vars:
   - `DATABASE_URL` — your Neon connection string
   - `AUTH_ACCESS_CODE` — any passphrase; **required in production**, it's
     what stops strangers from logging into your backend
   - `ANTHROPIC_API_KEY` / `REDIS_URL` — optional
   - `JWT_SECRET` is generated automatically
4. Run the idempotent migrations once against the same database:
   ```bash
   cd packages/backend
   DATABASE_URL=<neon-url> npx tsx scripts/migrate-2026-07-features.ts
   DATABASE_URL=<neon-url> npx tsx scripts/migrate-2026-07-batch2.ts
   DATABASE_URL=<neon-url> npx tsx scripts/migrate-2026-07-batch3.ts
   ```

In production the server refuses to boot without `DATABASE_URL`,
`JWT_SECRET` and `AUTH_ACCESS_CODE`, trusts the reverse proxy for client
IPs (rate limiting), restricts CORS to `ALLOWED_ORIGINS`, and shuts down
gracefully on SIGTERM.

### 2. Point the apps at it

On **each device** (desktop and phone), in lifeOS → Settings → Server:

1. **Backend** → `https://<your-service>.onrender.com/api`
2. **Access code** → the `AUTH_ACCESS_CODE` you chose

### 3. Phone build

```bash
cd apps/flutter
flutter build apk --release   # or: --dart-define=API_BASE_URL=https://.../api to bake the URL in
```

Install the APK, set Server + Access code in Settings, done. Health Connect
sync and (with Firebase configured) push reminders are phone-only bonuses.
For home-network-only use, skip Render and set the backend URL to
`http://<pc-lan-ip>:3000/api` instead — Android cleartext is already allowed.

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

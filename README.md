# Life Achiever 🌟

Welcome to **Life Achiever**, a comprehensive gamified life-management application that turns your daily routines into rewarding quests. Life Achiever tracks and syncs your tasks, fitness, nutrition, spending, and schedule across desktop and mobile.

---

## 🛠️ Technology Stack

Life Achiever is built on a modern, offline-first client-server architecture:

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
```

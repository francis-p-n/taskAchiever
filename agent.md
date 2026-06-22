# 🤖 Agent Context & Onboarding Guide

Welcome! This file serves as the single source of truth and onboarding context for any AI coding assistant working in this repository. Please read this file to understand the project structure, design rules, and historical changes before making modifications.

---

## 🎯 Project Overview & Mission

**SideQuest Achiever** is a gamified task tracker designed as a borderless Electron desktop app. It organizes life's personal milestones as "quests" with sub-steps ("roadmaps"), streaks, auto-categorization matching keywords, and satisfaction ratings. It is designed to act as an aesthetic front-end dashboard that maps directly to a user's Todoist workflow via API.

---

## 🛠️ Technology Stack

- **Runtime & Environment:** Electron (v33.0.0), Node.js
- **Persistence:** Local JSON configuration using `electron-store`
- **Frontend Stack:** Vanilla JS (ES6 modules), Vanilla CSS (Custom styling properties, transitions, and keyframe animations), HTML5
- **Fonts & Assets:** Google Fonts (Inter)
- **External Integrations:** Todoist Sync API

---

## 📂 Key Files & Directories

- [package.json](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/package.json): Lists dependencies (e.g. `electron-store`), build commands, metadata, and portable package target settings.
- [main.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/main.js): Node main process. Configures native borderless window options, handles file-system reads/writes to `electron-store`, and hosts Todoist API proxy fetches.
- [preload.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/preload.js): Preload script exposing IPC methods securely under `window.electronAPI`.
- [src/index.html](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/index.html): Renders layout (custom titlebar, navigation sidebar, modals, panels, and views).
- [src/styles/index.css](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/styles/index.css): Core design token layout (color values, variables, spacing rules, and font definitions).
- [src/styles/components.css](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/styles/components.css): Stylings for titlebar, cards, ring diagrams, lists, detail panels, rating widgets, and animations.
- **Renderer Script Modules (`src/js/`):**
  - [src/js/app.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/app.js): Coordinator. Hooks click listeners, window buttons, navigation views, and initializes sub-modules.
  - [src/js/store.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/store.js): Local CRUD storage, streaks tracker, and completions logger.
  - [src/js/categories.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/categories.js): Parsing rules engine categorizing titles to domains (Adventure, Creative, Scholarly, Achievement).
  - [src/js/todoist.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/todoist.js): Sync interface mapping tasks, labels, subtasks, and handling project imports.
  - [src/js/roadmap.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/roadmap.js): Subtask drag-and-drop renderer and editor.
  - [src/js/kpi.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/kpi.js): Analytics generator (category rings, top achievements, and heatmap calendar).
  - [src/js/suggestions.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/suggestions.js): Recommendation generator utilizing seasonal, category, and streak-based rules.
  - [src/js/ui.js](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/src/js/ui.js): Modal openers, ratings widgets, and generic UI widgets.

---

## ⚡ Active Context & Next Steps

### Current Focus
- The system is fully operational locally and integrates with Todoist.
- No active compile or runtime bugs have been reported.

### Next Steps / Backlog Priorities
1. Support queuing offline operations and replaying Todoist actions upon recovery.
2. Implement quest archiving to clean the viewport without losing historical analytics records.
3. Implement Monthly KPI overviews and global keyboard shortcuts.

---

## 📝 Changelog / Recent Edits

### 2026-06-22 (Agent: Antigravity)
- Modified `src/js/todoist.js` to call `importExistingTasks()` on every app startup (if a project ID exists) rather than just the first run, improving synchronization reliability.

### 2026-06-21 (Agent: Antigravity)
- Added Settings UI Panel allowing users to toggle Todoist sync, set API key, and configure yearly goals.
- Added AI-powered roadmap step generation (`llm.js`).
- Implemented Streak Protection/Freezer store logic powered by XP earned from completing quests.

### 2026-06-20 (Agent: Antigravity)
- Added initial autodocumentation assets for workspace onboarding:
  - Created [README.md](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/README.md) describing user installation, tech stack, and execution flows.
  - Created [architecture.md](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/architecture.md) explaining processes, components, IPC bridges, and schema configurations.
  - Created [todo.md](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/todo.md) compiling project roadmap achievements and future features.
  - Initialized [agent.md](file:///c:/Users/MSI/Desktop/Projects/taskAchiever/agent.md) as the central repository onboarding file.

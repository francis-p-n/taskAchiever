# 🎮 SideQuest Achiever

> A premium, desktop sidequest tracker that looks and feels exactly like **Todoist Pro (Dark Theme)**, integrated directly with your actual Todoist account.

SideQuest Achiever bridges the gap between everyday productivity and personal growth by transforming your actual Todoist project sections into gamified **Sidequests** across four major categories: **Adventure**, **Creative**, **Scholarly**, and **Achievement**.

![SideQuest Achiever Hero Banner](https://raw.githubusercontent.com/todoist/branding/master/assets/todoist-logo.png) *Todoist-inspired layout*

---

## 🌟 Core Features

- **🎯 Gamified Categories:** Auto-assigns and categorizes your imported quests into four disciplines:
  - 🏔️ **Adventure:** Outdoor exploration, sports, travel.
  - 🎨 **Creative:** Writing, music, cooking, art, building.
  - 📚 **Scholarly:** Reading, programming, certifications, research.
  - 🏆 **Achievement:** Fitness races, habit building, finances, networking.
- **📊 Year-in-Review KPIs:** Dynamic dashboards displaying:
  - 52-week activity heatmap (GitHub/Todoist style).
  - Category rings displaying progress in each category.
  - Streaks, total completions, and average quest fulfillment.
  - Rankings of the **Most Fulfilling** and **Most Achievable** sidequests.
- **🗺️ Actionable Roadmaps:** Breakdown individual quests into manageable sub-tasks (roadmap steps) synced as sub-tasks in Todoist. Includes AI-powered step generation.
- **🛡️ Streak Protection & XP:** Earn experience points from completing quests to purchase streak freezes, protecting your habits during vacations or days off.
- **💡 Intelligent Suggestion Engine:** Rule-based recommendations tailored to your under-represented categories, seasonal monthly events, and recent activity patterns.
- **🔄 Flawless Todoist Integration:** Bi-directional sync with the active `/api/v1` REST endpoints. Completing, updating, or adding tasks propagates instantly.

---

## 🚀 Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v16+)
- A [Todoist](https://todoist.com) account and your Developer API Key.

### Installation

1. Clone the repository or navigate to the directory:
   ```bash
   cd taskAchiever
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

### Running Locally (Development)

Run the application in developer mode:
   ```bash
   npm run dev
   ```

### Building the Windows Executable

To compile a production-ready Windows portable version:
   ```bash
   npm run build
   ```
The compiled binaries will be located in the `dist/` directory. If you run into privilege issues on Windows (e.g. `SeCreateSymbolicLinkPrivilege`), use the fully functioning unpacked build inside:
`dist/win-unpacked/SideQuest Achiever.exe`

---

## 🛠️ Configuration & Customization

The app automatically reads your Todoist API key from the local storage. By default, it uses the key:
`7511422301aff1a77af73d030a8daad9218f6e30`

You can change this or disable synchronization in the Settings panel inside the app.

---

## 📁 Repository Structure

```
taskAchiever/
├── main.js                 # Electron Main Process (IPC handlers & API Fetch helper)
├── preload.js              # Electron Context Bridge (IPC exposed APIs)
├── package.json            # Application dependencies and package commands
├── architecture.md         # In-depth system architecture overview
├── agent.md                # Context documentation for AI agents
├── todo.md                 # Project backlog and future roadmap
└── src/
    ├── index.html          # Application Single Page Layout
    ├── styles/             # Stylesheets (Vanilla CSS)
    │   ├── index.css       # Core variables & layout styling
    │   └── components.css  # UI component-specific styling
    └── js/                 # Renderer Javascript Modules
        ├── app.js          # Controller coordinating all modules
        ├── store.js        # Local persistence proxy (QuestStore)
        ├── todoist.js      # Sync engine with the Todoist API
        ├── kpi.js          # KPI Dashboard & activity heatmap
        ├── suggestions.js  # Rule-based suggestions engine
        ├── roadmap.js      # Steps/sub-tasks controller
        ├── categories.js   # Category metadata & autodetect rules
        └── ui.js           # UI notifications & dialog handlers
```

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE details.

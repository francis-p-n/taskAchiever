# 📋 Project Roadmap & Backlog

This file tracks the completed milestones, active tasks, and planned enhancements for **SideQuest Achiever**.

---

## 🚀 Milestones

### Completed Features (v1.0.0)
- [x] **Core Window Controls:** Custom dark titlebar with custom minimize, maximize, and close handlers.
- [x] **Quest Management System:** Create, update, and delete side quests with difficulty parameters and due dates.
- [x] **Roadmap Breakdown:** Step-by-step checklist support for quests with HTML5 drag-and-drop sorting.
- [x] **Auto-Categorization:** Rule-based keyword matching engine to sorting quests into Adventure, Creative, Scholarly, or Achievement.
- [x] **Analytics Dashboard:**
  - [x] Current and longest streak tracker.
  - [x] Category ring ratios (active vs. completed).
  - [x] Stars-based fulfillment system to rate completed quests.
  - [x] GitHub-style 365-day SVG/CSS activity heatmap.
- [x] **Todoist Integration:** Two-way sync mapping quests to project tasks, labels, and checklists.
- [x] **Smart Suggestions:** Seasonal suggestions, underrepresented category hints, and progression recommendations.

---

## 🛠️ Active Development / Immediate Backlog

- [ ] **Settings UI Panel:**
  - Add a dedicated view or modal for managing settings.
  - Allow users to customize their `yearlyGoal` and `todoistApiKey` directly within the app rather than editing configuration files.
  - Toggle Todoist synchronization status (`syncEnabled`) on/off manually.
- [ ] **Offline Synchronization Queue:**
  - Support queuing Todoist API calls when offline.
  - Replay sync actions automatically when connectivity is restored, preventing discrepancies.
- [ ] **Quest Archiving System:**
  - Introduce an "Archive" state for quests to hide them from the active list without permanently deleting history.
  - Allow viewing the archive to restore previously archived items.

---

## 🔮 Future Backlog & Enhancements

### UI/UX Polish
- [ ] **Global Keyboard Shortcuts:** Define system-wide hotkeys (e.g. `Ctrl+Alt+S` to spawn the quest entry form).
- [ ] **Sound Effects & Micro-Animations:** Sparkle effects on quest completion ratings, level-up sound alerts.
- [ ] **Visual Theme Engine:** Switch between glassmorphism, cyberpunk neon, or minimalist monochrome styles.

### Analytics Expansion
- [ ] **Monthly KPI Overviews:** Line/bar charts showing quest completion trends across months.
- [ ] **Fulfillment Correlator:** Insight reports displaying which categories correlate to the highest satisfaction.
- [ ] **Streak Protection/Freezers:** "Streak freeze" items purchased with quest experience points to protect habits during vacations.

### Customization
- [ ] **User-Defined Categories:** Edit, delete, or create categories, custom icons, and specify custom parsing keyword rules.
- [ ] **Multi-Level Checklists:** Support nesting checklists deep into subtasks for complex project planning.

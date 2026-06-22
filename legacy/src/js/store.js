/* ═══════════════════════════════════════════════════════════════════════════
   Store — Local data persistence via electron-store
   ═══════════════════════════════════════════════════════════════════════════ */

const QuestStore = (() => {
  // ─── Quest CRUD ────────────────────────────────────────────────────────
  async function getQuests() {
    return (await window.electronAPI.storeGet('quests')) || [];
  }

  async function getCompletedQuests() {
    return (await window.electronAPI.storeGet('completedQuests')) || [];
  }

  async function addQuest(quest) {
    const quests = await getQuests();
    quest.id = generateId();
    quest.createdAt = new Date().toISOString();
    quest.steps = quest.steps || [];
    quest.difficulty = quest.difficulty || 1;
    quest.fulfillment = null;
    quest.todoistId = quest.todoistId || null;
    quests.push(quest);
    await window.electronAPI.storeSet('quests', quests);
    return quest;
  }

  async function updateQuest(questId, updates) {
    const quests = await getQuests();
    const idx = quests.findIndex(q => q.id === questId);
    if (idx === -1) return null;
    quests[idx] = { ...quests[idx], ...updates, updatedAt: new Date().toISOString() };
    await window.electronAPI.storeSet('quests', quests);
    return quests[idx];
  }

  async function deleteQuest(questId) {
    let quests = await getQuests();
    quests = quests.filter(q => q.id !== questId);
    await window.electronAPI.storeSet('quests', quests);
  }

  async function completeQuest(questId, fulfillment) {
    const quests = await getQuests();
    const idx = quests.findIndex(q => q.id === questId);
    if (idx === -1) return null;

    const quest = quests[idx];
    quest.completedAt = new Date().toISOString();
    quest.fulfillment = fulfillment;

    // Move to completed
    const completed = await getCompletedQuests();
    completed.push(quest);
    await window.electronAPI.storeSet('completedQuests', completed);

    // Remove from active
    quests.splice(idx, 1);
    await window.electronAPI.storeSet('quests', quests);

    // Update stats
    await updateStats(quest);

    return quest;
  }

  // ─── Steps ─────────────────────────────────────────────────────────────
  async function addStep(questId, stepText) {
    const quests = await getQuests();
    const quest = quests.find(q => q.id === questId);
    if (!quest) return null;

    const step = {
      id: generateId(),
      text: stepText,
      completed: false,
      createdAt: new Date().toISOString(),
      todoistId: null
    };

    quest.steps = quest.steps || [];
    quest.steps.push(step);
    await window.electronAPI.storeSet('quests', quests);
    return step;
  }

  async function toggleStep(questId, stepId) {
    const quests = await getQuests();
    const quest = quests.find(q => q.id === questId);
    if (!quest) return;

    const step = quest.steps.find(s => s.id === stepId);
    if (step) {
      step.completed = !step.completed;
      step.completedAt = step.completed ? new Date().toISOString() : null;
    }
    await window.electronAPI.storeSet('quests', quests);
    return step;
  }

  async function deleteStep(questId, stepId) {
    const quests = await getQuests();
    const quest = quests.find(q => q.id === questId);
    if (!quest) return;

    quest.steps = quest.steps.filter(s => s.id !== stepId);
    await window.electronAPI.storeSet('quests', quests);
  }

  async function reorderSteps(questId, stepIds) {
    const quests = await getQuests();
    const quest = quests.find(q => q.id === questId);
    if (!quest) return;

    const stepsMap = {};
    quest.steps.forEach(s => stepsMap[s.id] = s);
    quest.steps = stepIds.map(id => stepsMap[id]).filter(Boolean);
    await window.electronAPI.storeSet('quests', quests);
  }

  // ─── Stats ─────────────────────────────────────────────────────────────
  async function updateStats(completedQuest) {
    const stats = (await window.electronAPI.storeGet('stats')) || {};
    const today = new Date().toISOString().split('T')[0];

    stats.totalCompleted = (stats.totalCompleted || 0) + 1;

    // XP calculation
    const xpEarned = (completedQuest.difficulty || 1) * 10;
    stats.experiencePoints = (stats.experiencePoints || 0) + xpEarned;
    stats.streakFreezes = stats.streakFreezes || 0;

    // Streak calculation
    const settings = await getSettings();
    const lastDate = stats.lastActiveDate;
    if (lastDate) {
      const last = new Date(lastDate);
      const now = new Date(today);
      const diffDays = Math.floor((now - last) / (1000 * 60 * 60 * 24));

      if (diffDays === 1) {
        stats.currentStreak = (stats.currentStreak || 0) + 1;
      } else if (diffDays > 1) {
        const missed = diffDays - 1;
        if (settings.autoFreeze !== false && stats.streakFreezes >= missed) {
          stats.streakFreezes -= missed;
          stats.currentStreak = (stats.currentStreak || 0) + 1;
        } else {
          stats.currentStreak = 1;
        }
      }
    } else {
      stats.currentStreak = 1;
    }

    stats.longestStreak = Math.max(stats.longestStreak || 0, stats.currentStreak);
    stats.lastActiveDate = today;

    // Activity log
    const activity = (await window.electronAPI.storeGet('activityLog')) || {};
    activity[today] = (activity[today] || 0) + 1;
    await window.electronAPI.storeSet('activityLog', activity);

    await window.electronAPI.storeSet('stats', stats);
    return stats;
  }

  async function getStats() {
    return (await window.electronAPI.storeGet('stats')) || {
      totalCompleted: 0,
      currentStreak: 0,
      longestStreak: 0,
      lastActiveDate: null,
      experiencePoints: 0,
      streakFreezes: 0
    };
  }

  async function getActivityLog() {
    return (await window.electronAPI.storeGet('activityLog')) || {};
  }

  async function getSettings() {
    return (await window.electronAPI.storeGet('settings')) || { 
      syncEnabled: true, 
      yearlyGoal: 52,
      theme: 'system',
      firstDayOfWeek: 'monday',
      enableSounds: true,
      autoFreeze: true
    };
  }

  async function updateSettings(updates) {
    const settings = await getSettings();
    const newSettings = { ...settings, ...updates };
    await window.electronAPI.storeSet('settings', newSettings);
    return newSettings;
  }

  async function getTodoistApiKey() {
    return (await window.electronAPI.storeGet('todoistApiKey')) || '';
  }

  async function updateTodoistApiKey(key) {
    await window.electronAPI.storeSet('todoistApiKey', key);
    return key;
  }

  async function buyStreakFreeze() {
    const stats = await getStats();
    stats.experiencePoints = stats.experiencePoints || 0;
    stats.streakFreezes = stats.streakFreezes || 0;

    if (stats.experiencePoints >= 50) {
      stats.experiencePoints -= 50;
      stats.streakFreezes += 1;
      await window.electronAPI.storeSet('stats', stats);
      return stats;
    }
    return null;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────
  function generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substring(2, 9);
  }

  function getQuestProgress(quest) {
    if (!quest.steps || quest.steps.length === 0) return 0;
    const done = quest.steps.filter(s => s.completed).length;
    return Math.round((done / quest.steps.length) * 100);
  }

  return {
    getQuests,
    getCompletedQuests,
    addQuest,
    updateQuest,
    deleteQuest,
    completeQuest,
    addStep,
    toggleStep,
    deleteStep,
    reorderSteps,
    getStats,
    getActivityLog,
    getSettings,
    updateSettings,
    getTodoistApiKey,
    updateTodoistApiKey,
    buyStreakFreeze,
    getQuestProgress,
    generateId
  };
})();

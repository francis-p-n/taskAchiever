/* ═══════════════════════════════════════════════════════════════════════════
   App — Main application controller
   ═══════════════════════════════════════════════════════════════════════════ */

const App = (() => {
  let currentView = 'quests';
  let currentFilter = 'all';
  let selectedQuestId = null;
  let questDifficultyWidget = null;
  let detailDifficultyWidget = null;
  let fulfillmentWidget = null;
  let pendingCompleteQuestId = null;

  // ─── Initialize ────────────────────────────────────────────────────────
  async function init() {
    // Window controls
    document.getElementById('btn-minimize').addEventListener('click', () => window.electronAPI.minimize());
    document.getElementById('btn-maximize').addEventListener('click', () => window.electronAPI.maximize());
    document.getElementById('btn-close').addEventListener('click', () => window.electronAPI.close());

    // Navigation
    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.addEventListener('click', () => switchView(btn.dataset.view));
    });

    // Category filters
    document.querySelectorAll('.category-filter').forEach(btn => {
      btn.addEventListener('click', () => {
        currentFilter = btn.dataset.category;
        document.querySelectorAll('.category-filter').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        if (currentView === 'quests') {
          renderQuestList();
        } else if (currentView === 'kpi') {
          KPI.render();
        } else if (currentView === 'suggestions') {
          Suggestions.render();
        }
      });
    });

    // New quest modal
    document.getElementById('btn-add-quest').addEventListener('click', openNewQuestModal);
    document.getElementById('btn-empty-add').addEventListener('click', openNewQuestModal);
    document.getElementById('btn-create-quest').addEventListener('click', createQuest);

    // Modal close buttons
    document.querySelectorAll('.modal-close').forEach(btn => {
      btn.addEventListener('click', () => UI.closeAllModals());
    });

    // Close modal on overlay click
    document.querySelectorAll('.modal-overlay').forEach(overlay => {
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) UI.closeAllModals();
      });
    });

    // Detail panel
    document.getElementById('btn-close-detail').addEventListener('click', () => {
      UI.closeDetailPanel();
      selectedQuestId = null;
    });

    // Detail panel field changes
    document.getElementById('detail-category').addEventListener('change', saveDetailChanges);
    document.getElementById('detail-due-date').addEventListener('change', saveDetailChanges);
    document.getElementById('detail-description').addEventListener('blur', saveDetailChanges);

    // Quest actions
    document.getElementById('btn-complete-quest').addEventListener('click', initiateCompleteQuest);
    document.getElementById('btn-delete-quest').addEventListener('click', deleteCurrentQuest);

    // Completion rating modal
    document.getElementById('btn-submit-rating').addEventListener('click', submitRating);
    document.getElementById('btn-skip-rating').addEventListener('click', () => submitRating(true));

    // Suggestions
    document.getElementById('btn-refresh-suggestions').addEventListener('click', () => Suggestions.render());

    // Suggestion card clicks (delegated)
    document.getElementById('suggestions-list').addEventListener('click', handleSuggestionClick);

    // Keyboard shortcut: Escape closes panels/modals
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        UI.closeAllModals();
        UI.closeDetailPanel();
        selectedQuestId = null;
      }
      // Ctrl+N = new quest
      if (e.ctrlKey && e.key === 'n') {
        e.preventDefault();
        openNewQuestModal();
      }
    });

    // Enter to create quest
    document.getElementById('quest-title').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') createQuest();
    });

    // Initialize difficulty widgets
    questDifficultyWidget = UI.initDifficultyRating('quest-difficulty');
    detailDifficultyWidget = UI.initDifficultyRating('detail-difficulty', (val) => {
      saveDetailChanges();
    });
    fulfillmentWidget = UI.initFulfillmentStars('fulfillment-stars');

    // Initialize sub-modules
    Roadmap.init();
    KPI.init();

    // Load data and render
    await renderQuestList();
    updateCategoryCounts();
    updateSidebarStats();

    // Initialize Todoist sync (non-blocking)
    TodoistSync.init().then(success => {
      if (success) {
        UI.toast('Connected to Todoist', 'success');
      } else {
        UI.toast('Running in offline mode', 'info');
      }
    });
  }

  // ─── View Switching ───────────────────────────────────────────────────
  function switchView(view) {
    currentView = view;

    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.view === view);
    });

    document.querySelectorAll('.view').forEach(v => {
      v.classList.toggle('active', v.id === `view-${view}`);
    });

    // Close detail panel when switching views
    UI.closeDetailPanel();
    selectedQuestId = null;

    // Render view-specific content
    if (view === 'kpi') KPI.render();
    if (view === 'suggestions') Suggestions.render();
  }

  // ─── Quest List Rendering ─────────────────────────────────────────────
  async function renderQuestList() {
    const quests = await QuestStore.getQuests();
    const container = document.getElementById('quest-list');
    const emptyState = document.getElementById('empty-state');

    // Filter
    const filtered = currentFilter === 'all'
      ? quests
      : quests.filter(q => q.category === currentFilter);

    // Clear existing cards (keep empty state)
    container.querySelectorAll('.quest-card').forEach(c => c.remove());

    if (filtered.length === 0) {
      emptyState.style.display = 'flex';
      return;
    }

    emptyState.style.display = 'none';

    // Sort: overdue first, then by creation date (newest first)
    filtered.sort((a, b) => {
      const aOverdue = a.dueDate && UI.isOverdue(a.dueDate);
      const bOverdue = b.dueDate && UI.isOverdue(b.dueDate);
      if (aOverdue && !bOverdue) return -1;
      if (!aOverdue && bOverdue) return 1;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });

    filtered.forEach(quest => {
      const card = createQuestCard(quest);
      container.insertBefore(card, emptyState);
    });
  }

  function createQuestCard(quest) {
    const progress = QuestStore.getQuestProgress(quest);
    const catInfo = Categories.getCategory(quest.category);
    const hasSteps = quest.steps && quest.steps.length > 0;
    const isOverdue = quest.dueDate && UI.isOverdue(quest.dueDate);

    const card = document.createElement('div');
    card.className = `quest-card ${selectedQuestId === quest.id ? 'active' : ''}`;
    card.dataset.category = quest.category;
    card.dataset.questId = quest.id;

    // Difficulty display
    const diffDisplay = Array.from({ length: 5 }, (_, i) =>
      `<span class="${i < (quest.difficulty || 1) ? 'filled' : 'empty'}">⚔️</span>`
    ).join('');

    card.innerHTML = `
      <div class="quest-checkbox" data-quest-id="${quest.id}"></div>
      <div class="quest-card-body">
        <div class="quest-card-title">
          ${quest.title}
        </div>
        <div class="quest-card-meta">
          <span class="quest-badge quest-badge-${quest.category}">${catInfo.icon} ${quest.category}</span>
          ${quest.originalSection ? `<span class="quest-tag">#${quest.originalSection}</span>` : ''}
          <span class="quest-difficulty">${diffDisplay}</span>
          ${hasSteps ? `
            <span class="quest-progress-mini">
              <span class="quest-progress-bar-mini">
                <span class="quest-progress-fill-mini" style="width: ${progress}%"></span>
              </span>
              <span>${progress}%</span>
            </span>
          ` : ''}
          ${quest.dueDate ? `
            <span class="quest-due ${isOverdue ? 'overdue' : ''}">
              📅 ${UI.formatDate(quest.dueDate)}
            </span>
          ` : ''}
        </div>
      </div>
    `;

    // Click card to open detail panel
    card.addEventListener('click', (e) => {
      if (e.target.closest('.quest-checkbox')) return;
      openQuestDetail(quest.id);
    });

    // Checkbox click to complete
    card.querySelector('.quest-checkbox').addEventListener('click', (e) => {
      e.stopPropagation();
      selectedQuestId = quest.id;
      initiateCompleteQuest();
    });

    return card;
  }

  // ─── Quest Detail Panel ───────────────────────────────────────────────
  async function openQuestDetail(questId) {
    selectedQuestId = questId;
    const quests = await QuestStore.getQuests();
    const quest = quests.find(q => q.id === questId);
    if (!quest) return;

    // Highlight active card
    document.querySelectorAll('.quest-card').forEach(c => {
      c.classList.toggle('active', c.dataset.questId === questId);
    });

    // Fill detail panel
    document.getElementById('detail-quest-title').textContent = quest.title;
    document.getElementById('detail-category').value = quest.category;
    document.getElementById('detail-due-date').value = quest.dueDate || '';
    document.getElementById('detail-description').value = quest.description || '';

    // Set difficulty
    if (detailDifficultyWidget) detailDifficultyWidget.setValue(quest.difficulty || 1);

    // Render roadmap steps
    await Roadmap.renderSteps(questId);

    UI.openDetailPanel();
  }

  async function saveDetailChanges() {
    if (!selectedQuestId) return;

    const updates = {
      category: document.getElementById('detail-category').value,
      dueDate: document.getElementById('detail-due-date').value || null,
      description: document.getElementById('detail-description').value,
      difficulty: detailDifficultyWidget ? detailDifficultyWidget.getValue() : 1
    };

    const quest = await QuestStore.updateQuest(selectedQuestId, updates);
    if (quest) {
      // Sync to Todoist
      TodoistSync.syncQuestToTodoist(quest);
      await renderQuestList();
      updateCategoryCounts();
    }
  }

  // ─── New Quest Modal ──────────────────────────────────────────────────
  function openNewQuestModal() {
    document.getElementById('quest-title').value = '';
    document.getElementById('quest-description').value = '';
    document.getElementById('quest-category').value = 'auto';
    document.getElementById('quest-due-date').value = '';
    if (questDifficultyWidget) questDifficultyWidget.setValue(1);

    UI.openModal('modal-overlay');
  }

  async function createQuest() {
    const title = document.getElementById('quest-title').value.trim();
    if (!title) {
      UI.toast('Please enter a quest title', 'error');
      return;
    }

    const description = document.getElementById('quest-description').value.trim();
    const categorySelect = document.getElementById('quest-category').value;
    const dueDate = document.getElementById('quest-due-date').value || null;
    const difficulty = questDifficultyWidget ? questDifficultyWidget.getValue() : 1;

    // Auto-detect or manual category
    const category = categorySelect === 'auto'
      ? Categories.autoDetect(title, description)
      : categorySelect;

    const quest = await QuestStore.addQuest({
      title,
      description,
      category,
      dueDate,
      difficulty: difficulty || 1
    });

    UI.closeAllModals();
    UI.toast(`Quest "${title}" created! (${Categories.getCategoryIcon(category)} ${category})`, 'success');

    // Sync to Todoist
    const todoistId = await TodoistSync.syncQuestToTodoist(quest);
    if (todoistId) {
      await QuestStore.updateQuest(quest.id, { todoistId });
      quest.todoistId = todoistId;
    }

    // Auto-generate roadmap steps with AI
    if (typeof LLM !== 'undefined') {
      try {
        const newSteps = await LLM.generateRoadmapSteps(quest.title, quest.description || '');
        if (newSteps && newSteps.length > 0) {
          for (const stepText of newSteps) {
            const step = await QuestStore.addStep(quest.id, stepText);
            if (step && quest.todoistId) {
               const stepTodoistId = await TodoistSync.syncStepToTodoist(quest, step);
               if (stepTodoistId) {
                 step.todoistId = stepTodoistId;
                 await QuestStore.updateQuest(quest.id, { steps: quest.steps });
               }
            }
          }
          UI.toast(`✨ Automatically generated ${newSteps.length} steps for "${quest.title}"`, 'success');
        }
      } catch (e) {
        console.error('Auto-generation of roadmap failed:', e);
      }
    }

    await renderQuestList();
    updateCategoryCounts();
    updateSidebarStats();
  }

  // ─── Complete Quest ───────────────────────────────────────────────────
  function initiateCompleteQuest() {
    if (!selectedQuestId) return;
    pendingCompleteQuestId = selectedQuestId;

    if (fulfillmentWidget) fulfillmentWidget.reset();
    UI.openModal('modal-rating-overlay');
  }

  async function submitRating(skip = false) {
    if (!pendingCompleteQuestId) return;

    const fulfillment = skip ? null : (fulfillmentWidget ? fulfillmentWidget.getValue() : null);
    const quest = await QuestStore.completeQuest(pendingCompleteQuestId, fulfillment);

    UI.closeAllModals();
    UI.closeDetailPanel();

    if (quest) {
      UI.toast(`🎉 Quest "${quest.title}" completed!`, 'success');

      // Complete in Todoist
      if (quest.todoistId) {
        await TodoistSync.completeInTodoist(quest.todoistId);
      }
    }

    selectedQuestId = null;
    pendingCompleteQuestId = null;

    await renderQuestList();
    updateCategoryCounts();
    updateSidebarStats();
  }

  // ─── Delete Quest ─────────────────────────────────────────────────────
  async function deleteCurrentQuest() {
    if (!selectedQuestId) return;

    const quests = await QuestStore.getQuests();
    const quest = quests.find(q => q.id === selectedQuestId);
    if (!quest) return;

    // Delete from Todoist
    if (quest.todoistId) {
      await TodoistSync.deleteInTodoist(quest.todoistId);
    }

    await QuestStore.deleteQuest(selectedQuestId);
    UI.closeDetailPanel();
    UI.toast('Quest deleted', 'info');

    selectedQuestId = null;
    await renderQuestList();
    updateCategoryCounts();
    updateSidebarStats();
  }

  // ─── Suggestion Handling ──────────────────────────────────────────────
  async function handleSuggestionClick(e) {
    const acceptBtn = e.target.closest('.btn-accept-suggestion');
    const dismissBtn = e.target.closest('.btn-dismiss-suggestion');

    if (acceptBtn) {
      const idx = parseInt(acceptBtn.dataset.index);
      const container = document.getElementById('suggestions-list');
      const suggestion = container._suggestions?.[idx];
      if (!suggestion) return;

      const quest = await QuestStore.addQuest({
        title: suggestion.title,
        description: suggestion.desc,
        category: suggestion.category,
        difficulty: suggestion.difficulty || 1
      });

      // Sync to Todoist
      const todoistId = await TodoistSync.syncQuestToTodoist(quest);
      if (todoistId) {
        await QuestStore.updateQuest(quest.id, { todoistId });
      }

      UI.toast(`Quest "${suggestion.title}" accepted!`, 'success');
      await Suggestions.render();
      updateCategoryCounts();
      updateSidebarStats();
    }

    if (dismissBtn) {
      const card = dismissBtn.closest('.suggestion-card');
      if (card) {
        card.style.transform = 'translateX(100px)';
        card.style.opacity = '0';
        setTimeout(() => card.remove(), 300);
      }
    }
  }

  // ─── Sidebar Updates ──────────────────────────────────────────────────
  async function updateCategoryCounts() {
    const quests = await QuestStore.getQuests();
    const counts = { all: quests.length, adventure: 0, creative: 0, scholarly: 0, achievement: 0 };

    quests.forEach(q => {
      if (counts[q.category] !== undefined) counts[q.category]++;
    });

    Object.entries(counts).forEach(([key, val]) => {
      const el = document.getElementById(`count-${key}`);
      if (el) el.textContent = val;
    });
  }

  async function updateSidebarStats() {
    const quests = await QuestStore.getQuests();
    const completed = await QuestStore.getCompletedQuests();
    const stats = await QuestStore.getStats();

    document.getElementById('stat-active').textContent = quests.length;
    document.getElementById('stat-completed').textContent = completed.length;
    document.getElementById('stat-streak').textContent = stats.currentStreak || 0;
  }

  // ─── Public API ────────────────────────────────────────────────────────
  async function refreshQuestList() {
    await renderQuestList();
    updateCategoryCounts();
    updateSidebarStats();
  }

  return {
    init,
    refreshQuestList,
    switchView,
    getCurrentFilter: () => currentFilter
  };
})();

// ─── Boot ────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  window.App = App;
  App.init();
});

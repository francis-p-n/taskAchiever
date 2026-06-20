/* ═══════════════════════════════════════════════════════════════════════════
   Roadmap — Quest step breakdown and progress management
   ═══════════════════════════════════════════════════════════════════════════ */

const Roadmap = (() => {
  let currentQuestId = null;
  let draggedEl = null;

  function init() {
    // Add step button
    document.getElementById('btn-add-step').addEventListener('click', addStep);

    // Enter key on step input
    document.getElementById('roadmap-new-step').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') addStep();
    });
  }

  // ─── Render Steps ──────────────────────────────────────────────────────
  async function renderSteps(questId) {
    currentQuestId = questId;
    const quests = await QuestStore.getQuests();
    const quest = quests.find(q => q.id === questId);
    if (!quest) return;

    const container = document.getElementById('roadmap-steps');
    const steps = quest.steps || [];

    container.innerHTML = '';

    if (steps.length === 0) {
      container.innerHTML = '<p style="color: var(--text-muted); font-size: var(--font-xs); padding: 8px; font-style: italic;">No steps yet. Break this quest into manageable steps!</p>';
    } else {
      steps.forEach((step, index) => {
        const stepEl = createStepElement(step, index);
        container.appendChild(stepEl);
      });
    }

    updateProgress(quest);
  }

  function createStepElement(step, index) {
    const el = document.createElement('div');
    el.className = 'roadmap-step';
    el.dataset.stepId = step.id;
    el.draggable = true;

    // Drag events
    el.addEventListener('dragstart', onDragStart);
    el.addEventListener('dragover', onDragOver);
    el.addEventListener('dragend', onDragEnd);
    el.addEventListener('drop', onDrop);

    // Checkbox
    const check = document.createElement('div');
    check.className = `step-check ${step.completed ? 'checked' : ''}`;
    check.innerHTML = step.completed ? '✓' : '';
    check.addEventListener('click', async (e) => {
      e.stopPropagation();
      await toggleStepCheck(step.id);
    });

    // Text
    const text = document.createElement('span');
    text.className = 'step-text';
    text.textContent = step.text;

    // Delete button
    const del = document.createElement('button');
    del.className = 'step-delete';
    del.innerHTML = '×';
    del.addEventListener('click', async (e) => {
      e.stopPropagation();
      await deleteStep(step.id);
    });

    el.appendChild(check);
    el.appendChild(text);
    el.appendChild(del);

    return el;
  }

  // ─── Step Operations ──────────────────────────────────────────────────
  async function addStep() {
    const input = document.getElementById('roadmap-new-step');
    const text = input.value.trim();
    if (!text || !currentQuestId) return;

    const step = await QuestStore.addStep(currentQuestId, text);
    input.value = '';

    if (step) {
      // Sync step to Todoist
      const quests = await QuestStore.getQuests();
      const quest = quests.find(q => q.id === currentQuestId);
      if (quest && quest.todoistId) {
        const todoistId = await TodoistSync.syncStepToTodoist(quest, step);
        if (todoistId) {
          step.todoistId = todoistId;
          await QuestStore.updateQuest(currentQuestId, { steps: quest.steps });
        }
      }

      await renderSteps(currentQuestId);
      // Update quest card progress
      if (window.App) App.refreshQuestList();
    }
  }



  async function toggleStepCheck(stepId) {
    if (!currentQuestId) return;

    const step = await QuestStore.toggleStep(currentQuestId, stepId);
    await renderSteps(currentQuestId);

    // Complete/reopen in Todoist
    if (step && step.todoistId) {
      if (step.completed) {
        await TodoistSync.completeInTodoist(step.todoistId);
      }
    }

    if (window.App) App.refreshQuestList();
  }

  async function deleteStep(stepId) {
    if (!currentQuestId) return;

    // Get step before deleting for Todoist sync
    const quests = await QuestStore.getQuests();
    const quest = quests.find(q => q.id === currentQuestId);
    const step = quest?.steps?.find(s => s.id === stepId);

    await QuestStore.deleteStep(currentQuestId, stepId);
    await renderSteps(currentQuestId);

    // Delete from Todoist
    if (step?.todoistId) {
      await TodoistSync.deleteInTodoist(step.todoistId);
    }

    if (window.App) App.refreshQuestList();
  }

  // ─── Progress ──────────────────────────────────────────────────────────
  function updateProgress(quest) {
    const steps = quest.steps || [];
    const total = steps.length;
    const done = steps.filter(s => s.completed).length;
    const pct = total > 0 ? Math.round((done / total) * 100) : 0;

    document.getElementById('roadmap-progress-label').textContent = `${done} / ${total} steps`;
    document.getElementById('roadmap-progress-fill').style.width = `${pct}%`;
  }

  // ─── Drag & Drop ──────────────────────────────────────────────────────
  function onDragStart(e) {
    draggedEl = e.currentTarget;
    draggedEl.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
  }

  function onDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    const target = e.currentTarget;
    if (target === draggedEl) return;

    const container = document.getElementById('roadmap-steps');
    const children = [...container.children];
    const draggedIdx = children.indexOf(draggedEl);
    const targetIdx = children.indexOf(target);

    if (draggedIdx < targetIdx) {
      target.after(draggedEl);
    } else {
      target.before(draggedEl);
    }
  }

  function onDragEnd(e) {
    if (draggedEl) {
      draggedEl.classList.remove('dragging');
      draggedEl = null;
    }
    saveStepOrder();
  }

  function onDrop(e) {
    e.preventDefault();
  }

  async function saveStepOrder() {
    if (!currentQuestId) return;

    const container = document.getElementById('roadmap-steps');
    const stepIds = [...container.children].map(el => el.dataset.stepId).filter(Boolean);
    await QuestStore.reorderSteps(currentQuestId, stepIds);
  }

  return {
    init,
    renderSteps
  };
})();

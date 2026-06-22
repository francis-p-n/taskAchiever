/* ═══════════════════════════════════════════════════════════════════════════
   Todoist — API integration layer
   ═══════════════════════════════════════════════════════════════════════════ */

const TodoistSync = (() => {
  let projectId = null;
  let matchingProjects = [];
  let labelIds = {};
  let isSyncing = false;

  // Project name → category mapping for the user's existing Todoist structure
  const PROJECT_CATEGORY_MAP = {
    'adventure': 'adventure',
    '2026 kpi': 'achievement',
    '2025 kpi': 'achievement',
    '2027 kpi': 'achievement',
    'creative': 'creative',
    'scholarly': 'scholarly',
    'achievement and awards': 'achievement',
    'achievement': 'achievement',
    'short film // content creation': 'creative',
    'short film': 'creative',
    'content creation': 'creative',
    'journalism topics': 'scholarly',
    'journalism': 'scholarly',
    'coding projects': 'achievement',
    'coding': 'achievement'
  };

  // ─── Initialize ────────────────────────────────────────────────────────
  async function init() {
    try {
      const settings = await QuestStore.getSettings();
      if (!settings.syncEnabled) {
        UI.setSyncStatus('', 'Sync Disabled');
        return false;
      }
      
      const apiKey = await QuestStore.getTodoistApiKey();
      if (!apiKey) {
        UI.setSyncStatus('error', 'No API Key');
        return false;
      }

      UI.setSyncStatus('syncing', 'Connecting...');

      // Get or create the SideQuests project
      projectId = await window.electronAPI.storeGet('todoistProjectId');

      if (!projectId) {
        projectId = await ensureProject();
      }

      // Verify project still exists
      try {
        const projects = await window.electronAPI.todoist.getProjects();
        const exists = projects.find(p => p.id === projectId);
        if (!exists) {
          projectId = await ensureProject();
        }
        
        // Update matching projects list based on categories
        matchingProjects = projects.filter(p => {
          const key = p.name.toLowerCase().trim();
          return key.includes('side quest') || key.includes('sidequest') || PROJECT_CATEGORY_MAP[key] !== undefined;
        });
      } catch (err) {
        console.warn('Could not verify project, will create on next sync:', err.message);
      }

      // Ensure category labels exist
      await ensureLabels();

      // Import existing tasks
      const imported = await window.electronAPI.storeGet('todoistImported');
      if (projectId) {
        await importExistingTasks();
        if (!imported) {
          await window.electronAPI.storeSet('todoistImported', true);
        }
      }

      UI.setSyncStatus('', 'Synced');
      return true;
    } catch (err) {
      console.error('Todoist init failed:', err);
      UI.setSyncStatus('error', 'Offline');
      return false;
    }
  }

  async function ensureProject() {
    try {
      const projects = await window.electronAPI.todoist.getProjects();

      // Look for existing "Side Quests" project (user's actual project name)
      let project = projects.find(p =>
        p.name.toLowerCase().includes('side quest') ||
        p.name.toLowerCase().includes('sidequest')
      );

      if (!project) {
        project = await window.electronAPI.todoist.createProject({
          name: '🎮 SideQuests',
          color: 'grape'
        });
      }

      await window.electronAPI.storeSet('todoistProjectId', project.id);
      return project.id;
    } catch (err) {
      console.error('Failed to ensure project:', err);
      return null;
    }
  }

  // ─── Import existing Todoist tasks ─────────────────────────────────────
  async function importExistingTasks() {
    try {
      UI.setSyncStatus('syncing', 'Importing tasks...');

      // Map of project id to category
      const projectCatMap = {};
      const projectNameMap = {};
      matchingProjects.forEach(p => {
        const key = p.name.toLowerCase().trim();
        projectCatMap[p.id] = PROJECT_CATEGORY_MAP[key] || null;
        projectNameMap[p.id] = p.name;
      });

      // Get all tasks across all matching projects
      const tasksPromises = matchingProjects.map(p => window.electronAPI.todoist.getTasks({ project_id: p.id }));
      const tasksArray = await Promise.all(tasksPromises);
      const tasks = tasksArray.flat();
      
      if (!tasks || tasks.length === 0) return;

      // Filter to top-level tasks only
      const topLevelTasks = tasks.filter(t => !t.parent_id);
      const subTasks = tasks.filter(t => t.parent_id);

      const existingQuests = await QuestStore.getQuests();
      const existingTodoistIds = new Set(existingQuests.map(q => q.todoistId).filter(Boolean));

      let importCount = 0;
      for (const task of topLevelTasks) {
        if (existingTodoistIds.has(task.id)) continue; // Skip already imported

        // Determine category from project or auto-detect
        const category = projectCatMap[task.project_id] || Categories.autoDetect(task.content);
          
        // Use project name as original section if it's not the default
        const originalSection = projectNameMap[task.project_id] !== 'Side Quests' ? projectNameMap[task.project_id] : null;

        // Clean title (remove emoji prefixes if any)
        const title = task.content.replace(/^[🗺️🎨📚🏆]\s*/, '');

        // Build steps from sub-tasks
        const taskSubTasks = subTasks.filter(st => st.parent_id === task.id);
        const steps = taskSubTasks.map(st => ({
          id: QuestStore.generateId(),
          text: st.content,
          completed: st.is_completed || false,
          todoistId: st.id,
          createdAt: st.created_at || new Date().toISOString()
        }));

        const quest = await QuestStore.addQuest({
          title,
          description: task.description || '',
          category,
          originalSection,
          difficulty: Math.min(task.priority || 1, 5),
          dueDate: task.due?.date || null,
          todoistId: task.id,
          steps
        });

        importCount++;
      }

      if (importCount > 0) {
        UI.toast(`Imported ${importCount} quests from Todoist!`, 'success');
        if (window.App) App.refreshQuestList();
      }
    } catch (err) {
      console.error('Failed to import existing tasks:', err);
    }
  }

  async function ensureLabels() {
    try {
      const existing = await window.electronAPI.todoist.getLabels();
      const categoryLabels = {
        adventure: 'sidequest-adventure',
        creative: 'sidequest-creative',
        scholarly: 'sidequest-scholarly',
        achievement: 'sidequest-achievement'
      };

      for (const [cat, labelName] of Object.entries(categoryLabels)) {
        let label = existing.find(l => l.name === labelName);
        if (!label) {
          try {
            label = await window.electronAPI.todoist.createLabel({
              name: labelName,
              color: getLabelColor(cat)
            });
          } catch (e) {
            // Label might already exist due to race condition
            const refreshed = await window.electronAPI.todoist.getLabels();
            label = refreshed.find(l => l.name === labelName);
          }
        }
        if (label) labelIds[cat] = label.id;
      }
    } catch (err) {
      console.warn('Failed to ensure labels:', err);
    }
  }

  function getLabelColor(category) {
    const map = {
      adventure: 'yellow',
      creative: 'grape',
      scholarly: 'blue',
      achievement: 'green'
    };
    return map[category] || 'charcoal';
  }

  // ─── Sync Operations ──────────────────────────────────────────────────
  async function syncQuestToTodoist(quest) {
    if (!projectId) return null;
    const settings = await QuestStore.getSettings();
    if (!settings.syncEnabled) return null;

    try {
      // Find the best project ID to use
      let targetProjectId = projectId;
      
      const matchingProj = matchingProjects.find(p => {
         const key = p.name.toLowerCase().trim();
         return PROJECT_CATEGORY_MAP[key] === quest.category;
      });
      if (matchingProj) {
         targetProjectId = matchingProj.id;
      }

      const data = {
        content: `${Categories.getCategoryIcon(quest.category)} ${quest.title}`,
        description: quest.description || '',
        project_id: targetProjectId,
        labels: labelIds[quest.category] ? [labelIds[quest.category].toString()] : [],
        priority: Math.min(quest.difficulty || 1, 4),
        due_string: quest.dueDate || undefined
      };

      // Remove undefined values
      Object.keys(data).forEach(key => data[key] === undefined && delete data[key]);

      if (quest.todoistId) {
        // Update existing
        await window.electronAPI.todoist.updateTask(quest.todoistId, data);
        return quest.todoistId;
      } else {
        // Create new
        const task = await window.electronAPI.todoist.createTask(data);
        return task.id;
      }
    } catch (err) {
      console.error('Failed to sync quest to Todoist:', err);
      UI.toast('Failed to sync to Todoist', 'error');
      return null;
    }
  }

  async function syncStepToTodoist(quest, step) {
    if (!projectId || !quest.todoistId) return null;
    const settings = await QuestStore.getSettings();
    if (!settings.syncEnabled) return null;

    try {
      const data = {
        content: step.text,
        parent_id: quest.todoistId
      };

      if (step.todoistId) {
        await window.electronAPI.todoist.updateTask(step.todoistId, { content: step.text });
        return step.todoistId;
      } else {
        const task = await window.electronAPI.todoist.createTask(data);
        return task.id;
      }
    } catch (err) {
      console.error('Failed to sync step to Todoist:', err);
      return null;
    }
  }

  async function completeInTodoist(todoistId) {
    if (!todoistId) return;
    const settings = await QuestStore.getSettings();
    if (!settings.syncEnabled) return;

    try {
      await window.electronAPI.todoist.closeTask(todoistId);
    } catch (err) {
      console.error('Failed to complete in Todoist:', err);
    }
  }

  async function deleteInTodoist(todoistId) {
    if (!todoistId) return;
    const settings = await QuestStore.getSettings();
    if (!settings.syncEnabled) return;

    try {
      await window.electronAPI.todoist.deleteTask(todoistId);
    } catch (err) {
      console.error('Failed to delete in Todoist:', err);
    }
  }

  // ─── Pull from Todoist ─────────────────────────────────────────────────
  async function pullFromTodoist() {
    if (!projectId || isSyncing) return [];
    
    const settings = await QuestStore.getSettings();
    if (!settings.syncEnabled) return [];

    isSyncing = true;
    UI.setSyncStatus('syncing', 'Syncing...');

    try {
      const tasksPromises = matchingProjects.map(p => window.electronAPI.todoist.getTasks({ project_id: p.id }));
      const tasksArray = await Promise.all(tasksPromises);
      const tasks = tasksArray.flat();
      UI.setSyncStatus('', 'Synced');
      return tasks || [];
    } catch (err) {
      console.error('Failed to pull from Todoist:', err);
      UI.setSyncStatus('error', 'Sync failed');
      return [];
    } finally {
      isSyncing = false;
    }
  }

  return {
    init,
    syncQuestToTodoist,
    syncStepToTodoist,
    completeInTodoist,
    deleteInTodoist,
    pullFromTodoist
  };
})();

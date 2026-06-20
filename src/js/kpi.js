/* ═══════════════════════════════════════════════════════════════════════════
   KPI — Yearly dashboard with charts and analytics
   ═══════════════════════════════════════════════════════════════════════════ */

const KPI = (() => {
  let currentYear = new Date().getFullYear();

  function init() {
    document.getElementById('kpi-year-prev').addEventListener('click', () => {
      currentYear--;
      render();
    });

    document.getElementById('kpi-year-next').addEventListener('click', () => {
      currentYear++;
      render();
    });
  }

  async function render() {
    const yearDisplay = document.getElementById('kpi-year-display');
    const yearLabel = document.getElementById('kpi-year-label');
    yearDisplay.textContent = currentYear;
    yearLabel.textContent = `${currentYear} Quest Performance`;

    let quests = await QuestStore.getQuests();
    let completed = await QuestStore.getCompletedQuests();
    const stats = await QuestStore.getStats();
    const settings = await QuestStore.getSettings();
    const activityLog = await QuestStore.getActivityLog();

    const currentFilter = window.App ? window.App.getCurrentFilter() : 'all';
    if (currentFilter !== 'all') {
      quests = quests.filter(q => q.category === currentFilter);
      completed = completed.filter(q => q.category === currentFilter);
    }

    // Filter completed quests by year
    const yearCompleted = completed.filter(q => {
      return q.completedAt && new Date(q.completedAt).getFullYear() === currentYear;
    });

    // ─── KPI Cards ────────────────────────────────────────────────────
    const totalCompleted = yearCompleted.length;
    const goal = settings.yearlyGoal || 52;
    const completionRate = Math.round((totalCompleted / goal) * 100);

    document.getElementById('kpi-total-completed').textContent = totalCompleted;
    document.getElementById('kpi-completion-rate').textContent = `${completionRate}% of ${goal} goal`;

    document.getElementById('kpi-streak').textContent = stats.currentStreak || 0;
    document.getElementById('kpi-longest-streak').textContent = `Longest: ${stats.longestStreak || 0} days`;

    // Average fulfillment
    const ratedQuests = yearCompleted.filter(q => q.fulfillment && q.fulfillment > 0);
    const avgFulfillment = ratedQuests.length > 0
      ? (ratedQuests.reduce((sum, q) => sum + q.fulfillment, 0) / ratedQuests.length).toFixed(1)
      : '—';
    document.getElementById('kpi-avg-fulfillment').textContent = avgFulfillment;

    // Active quests
    document.getElementById('kpi-active-quests').textContent = quests.length;
    const avgProgress = quests.length > 0
      ? Math.round(quests.reduce((sum, q) => sum + QuestStore.getQuestProgress(q), 0) / quests.length)
      : 0;
    document.getElementById('kpi-avg-progress').textContent = `${avgProgress}% avg progress`;

    // ─── Category Rings ───────────────────────────────────────────────
    renderCategoryRings(yearCompleted, quests);

    // ─── Most Fulfilling ──────────────────────────────────────────────
    renderFulfillingList(yearCompleted);

    // ─── Most Achievable ─────────────────────────────────────────────
    await renderAchievableList(quests);

    // ─── Heatmap ─────────────────────────────────────────────────────
    renderHeatmap(activityLog);
  }

  // ─── Category Ring Charts ─────────────────────────────────────────────
  function renderCategoryRings(completed, active) {
    const container = document.getElementById('category-rings');
    container.innerHTML = '';

    const categories = ['adventure', 'creative', 'scholarly', 'achievement'];
    const circumference = 2 * Math.PI * 40; // radius = 40

    categories.forEach(cat => {
      const catInfo = Categories.getCategory(cat);
      const doneCount = completed.filter(q => q.category === cat).length;
      const activeCount = active.filter(q => q.category === cat).length;
      const total = doneCount + activeCount;
      const pct = total > 0 ? Math.round((doneCount / total) * 100) : 0;
      const offset = circumference - (circumference * pct / 100);

      const card = document.createElement('div');
      card.className = 'ring-card';
      card.innerHTML = `
        <svg class="ring-svg" viewBox="0 0 100 100">
          <circle class="ring-bg" cx="50" cy="50" r="40"/>
          <circle class="ring-fill" cx="50" cy="50" r="40"
            stroke="${catInfo.color}"
            stroke-dasharray="${circumference}"
            stroke-dashoffset="${offset}"
          />
          <text x="50" y="50" text-anchor="middle" dy="0.35em"
            fill="${catInfo.color}" font-size="18" font-weight="800"
            style="transform: rotate(90deg); transform-origin: center;"
          >${pct}%</text>
        </svg>
        <div class="ring-label">
          <span>${catInfo.icon}</span>
          <span>${catInfo.name}</span>
        </div>
        <div style="font-size: var(--font-xs); color: var(--text-muted);">
          ${doneCount} done · ${activeCount} active
        </div>
      `;
      container.appendChild(card);
    });
  }

  // ─── Most Fulfilling List ─────────────────────────────────────────────
  function renderFulfillingList(completed) {
    const container = document.getElementById('kpi-fulfilling-list');
    const rated = completed
      .filter(q => q.fulfillment && q.fulfillment > 0)
      .sort((a, b) => b.fulfillment - a.fulfillment)
      .slice(0, 5);

    if (rated.length === 0) {
      container.innerHTML = '<p class="kpi-empty">Complete quests and rate them to see your top picks</p>';
      return;
    }

    container.innerHTML = rated.map((q, i) => `
      <div class="kpi-list-item">
        <span class="rank">${i + 1}</span>
        <div class="info">
          <div class="name">${Categories.getCategoryIcon(q.category)} ${q.title}</div>
          <div class="sub">${q.category} · completed ${formatRelative(q.completedAt)}</div>
        </div>
        <span class="score">${'★'.repeat(q.fulfillment)}</span>
      </div>
    `).join('');
  }

  // ─── Most Achievable List ─────────────────────────────────────────────
  async function renderAchievableList(quests) {
    const container = document.getElementById('kpi-achievable-list');
    container.innerHTML = '<p class="kpi-empty">Analyzing quests with AI...</p>';

    // Sort by: low difficulty first, then high progress
    let scoredQuests = [...quests]
      .map(q => {
        const progress = QuestStore.getQuestProgress(q);
        const score = (6 - (q.difficulty || 3)) * 20 + progress;
        return { ...q, progress, score };
      });

    // Enhance with LLM if available
    if (typeof LLM !== 'undefined') {
      scoredQuests = await LLM.enhanceAchievableScoring(scoredQuests);
    }

    const sorted = scoredQuests.sort((a, b) => b.score - a.score).slice(0, 5);

    if (sorted.length === 0) {
      container.innerHTML = '<p class="kpi-empty">Add quests with difficulty ratings to see recommendations</p>';
      return;
    }

    container.innerHTML = sorted.map((q, i) => `
      <div class="kpi-list-item">
        <span class="rank">${i + 1}</span>
        <div class="info">
          <div class="name">${Categories.getCategoryIcon(q.category)} ${q.title}</div>
          <div class="sub">Difficulty: ${'⚔️'.repeat(q.difficulty || 1)} · ${q.progress}% done</div>
        </div>
        <span class="score" style="color: var(--achievement);">${q.progress}%</span>
      </div>
    `).join('');
  }

  // ─── Activity Heatmap ─────────────────────────────────────────────────
  function renderHeatmap(activityLog) {
    const container = document.getElementById('kpi-heatmap');
    container.innerHTML = '';

    const grid = document.createElement('div');
    grid.className = 'heatmap-grid';

    // Generate all days of the year
    const startDate = new Date(currentYear, 0, 1);
    const endDate = new Date(currentYear, 11, 31);

    // Adjust to start on Sunday
    const firstDay = new Date(startDate);
    firstDay.setDate(firstDay.getDate() - firstDay.getDay());

    const today = new Date();

    for (let d = new Date(firstDay); d <= endDate || d.getDay() !== 0; d.setDate(d.getDate() + 1)) {
      const dateStr = d.toISOString().split('T')[0];
      const count = activityLog[dateStr] || 0;
      const isFuture = d > today;

      const level = isFuture ? 0 : count === 0 ? 0 : count === 1 ? 1 : count === 2 ? 2 : count <= 4 ? 3 : 4;

      const cell = document.createElement('div');
      cell.className = 'heatmap-cell';
      cell.dataset.level = level;
      cell.title = `${dateStr}: ${count} quest${count !== 1 ? 's' : ''}`;

      if (isFuture) cell.style.opacity = '0.3';

      grid.appendChild(cell);
    }

    container.appendChild(grid);

    // Month labels
    const months = document.createElement('div');
    months.className = 'heatmap-months';
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    monthNames.forEach(m => {
      const span = document.createElement('span');
      span.textContent = m;
      months.appendChild(span);
    });
    container.appendChild(months);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────
  function formatRelative(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const now = new Date();
    const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return 'today';
    if (diffDays === 1) return 'yesterday';
    if (diffDays < 7) return `${diffDays}d ago`;
    if (diffDays < 30) return `${Math.floor(diffDays / 7)}w ago`;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  return { init, render };
})();

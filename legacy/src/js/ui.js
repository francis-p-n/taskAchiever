/* ═══════════════════════════════════════════════════════════════════════════
   UI Utilities — Modals, Toasts, DOM helpers
   ═══════════════════════════════════════════════════════════════════════════ */

const UI = (() => {
  // ─── Toast Notifications ────────────────────────────────────────────────
  function toast(message, type = 'info', duration = 3000) {
    const container = document.getElementById('toast-container');
    const el = document.createElement('div');
    el.className = `toast toast-${type}`;
    el.textContent = message;
    container.appendChild(el);

    setTimeout(() => {
      el.classList.add('toast-out');
      el.addEventListener('animationend', () => el.remove());
    }, duration);
  }

  // ─── Modal Management ──────────────────────────────────────────────────
  function openModal(overlayId) {
    const overlay = document.getElementById(overlayId);
    if (overlay) {
      overlay.classList.add('open');
      const firstInput = overlay.querySelector('input, textarea, select');
      if (firstInput) setTimeout(() => firstInput.focus(), 100);
    }
  }

  function closeModal(overlayId) {
    const overlay = document.getElementById(overlayId);
    if (overlay) overlay.classList.remove('open');
  }

  function closeAllModals() {
    document.querySelectorAll('.modal-overlay.open').forEach(m => m.classList.remove('open'));
  }

  // ─── Detail Panel ──────────────────────────────────────────────────────
  function openDetailPanel() {
    document.getElementById('detail-panel').classList.add('open');
  }

  function closeDetailPanel() {
    document.getElementById('detail-panel').classList.remove('open');
    document.querySelectorAll('.quest-card.active').forEach(c => c.classList.remove('active'));
  }

  // ─── DOM Helpers ───────────────────────────────────────────────────────
  function $(selector) {
    return document.querySelector(selector);
  }

  function $$(selector) {
    return document.querySelectorAll(selector);
  }

  function createElement(tag, attrs = {}, children = []) {
    const el = document.createElement(tag);
    Object.entries(attrs).forEach(([key, val]) => {
      if (key === 'className') el.className = val;
      else if (key === 'textContent') el.textContent = val;
      else if (key === 'innerHTML') el.innerHTML = val;
      else if (key.startsWith('data-')) el.setAttribute(key, val);
      else if (key.startsWith('on')) el[key] = val;
      else el.setAttribute(key, val);
    });
    children.forEach(child => {
      if (typeof child === 'string') el.appendChild(document.createTextNode(child));
      else if (child) el.appendChild(child);
    });
    return el;
  }

  // ─── Difficulty Stars ──────────────────────────────────────────────────
  function initDifficultyRating(containerId, onChange) {
    const container = document.getElementById(containerId);
    if (!container) return;

    let currentValue = 0;
    const stars = container.querySelectorAll('.diff-star');

    function updateStars(value) {
      stars.forEach((star, i) => {
        star.classList.toggle('active', i < value);
      });
    }

    stars.forEach(star => {
      star.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        currentValue = parseInt(star.dataset.value);
        updateStars(currentValue);
        if (onChange) onChange(currentValue);
      });
    });

    return {
      getValue: () => currentValue,
      setValue: (v) => { currentValue = v; updateStars(v); },
      reset: () => { currentValue = 0; updateStars(0); }
    };
  }

  // ─── Fulfillment Stars ─────────────────────────────────────────────────
  function initFulfillmentStars(containerId, onChange) {
    const container = document.getElementById(containerId);
    if (!container) return;

    let currentValue = 0;
    const stars = container.querySelectorAll('.star-btn');
    const label = document.getElementById('rating-label');

    const labels = ['', 'Meh', 'Okay', 'Good', 'Great', 'Life-changing!'];

    function updateStars(value) {
      stars.forEach((star, i) => {
        star.classList.toggle('active', i < value);
      });
      if (label) label.textContent = labels[value] || 'Select a rating';
    }

    stars.forEach(star => {
      star.addEventListener('click', (e) => {
        e.preventDefault();
        currentValue = parseInt(star.dataset.value);
        updateStars(currentValue);
        if (onChange) onChange(currentValue);
      });
    });

    return {
      getValue: () => currentValue,
      setValue: (v) => { currentValue = v; updateStars(v); },
      reset: () => { currentValue = 0; updateStars(0); }
    };
  }

  // ─── Sync Status ───────────────────────────────────────────────────────
  function setSyncStatus(status, label) {
    const indicator = document.getElementById('sync-status');
    const labelEl = indicator.querySelector('.sync-label');
    indicator.className = `sync-indicator ${status}`;
    labelEl.textContent = label || status;
  }

  // ─── Date Formatting ───────────────────────────────────────────────────
  function formatDate(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const now = new Date();
    const diffDays = Math.floor((date - now) / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Tomorrow';
    if (diffDays === -1) return 'Yesterday';
    if (diffDays < -1) return `${Math.abs(diffDays)}d overdue`;
    if (diffDays <= 7) return `${diffDays}d left`;

    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  function isOverdue(dateStr) {
    if (!dateStr) return false;
    return new Date(dateStr) < new Date(new Date().toDateString());
  }

  return {
    toast,
    openModal,
    closeModal,
    closeAllModals,
    openDetailPanel,
    closeDetailPanel,
    $, $$,
    createElement,
    initDifficultyRating,
    initFulfillmentStars,
    setSyncStatus,
    formatDate,
    isOverdue
  };
})();

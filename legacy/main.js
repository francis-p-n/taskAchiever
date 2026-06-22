const { app, BrowserWindow, ipcMain, nativeTheme } = require('electron');
const path = require('path');
const Store = require('electron-store');

// ─── Electron Store Schema ───────────────────────────────────────────────────
const store = new Store({
  name: 'sidequest-data',
  defaults: {
    todoistApiKey: '7511422301aff1a77af73d030a8daad9218f6e30',
    todoistProjectId: null,
    quests: [],
    completedQuests: [],
    settings: {
      syncEnabled: true,
      yearlyGoal: 52
    },
    stats: {
      totalCompleted: 0,
      currentStreak: 0,
      longestStreak: 0,
      lastActiveDate: null
    }
  }
});

let mainWindow;

function createWindow() {
  nativeTheme.themeSource = 'dark';

  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 960,
    minHeight: 640,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#0F0F1A',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    },
    show: false
  });

  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'));

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ─── Todoist API Helper ──────────────────────────────────────────────────────
const TODOIST_BASE = 'https://api.todoist.com/api/v1';

async function todoistFetch(endpoint, options = {}) {
  const apiKey = store.get('todoistApiKey');
  if (!apiKey) throw new Error('No Todoist API key configured');

  const url = `${TODOIST_BASE}${endpoint}`;
  const headers = {
    'Authorization': `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
    ...options.headers
  };

  const response = await fetch(url, { ...options, headers });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Todoist API error ${response.status}: ${text}`);
  }

  if (response.status === 204) return null;
  const data = await response.json();
  return data.results !== undefined ? data.results : data;
}

// ─── IPC Handlers: Window Controls ───────────────────────────────────────────
ipcMain.handle('window:minimize', () => mainWindow?.minimize());
ipcMain.handle('window:maximize', () => {
  if (mainWindow?.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow?.maximize();
  }
});
ipcMain.handle('window:close', () => mainWindow?.close());
ipcMain.handle('window:isMaximized', () => mainWindow?.isMaximized());

// ─── IPC Handlers: Store ─────────────────────────────────────────────────────
ipcMain.handle('store:get', (_, key) => store.get(key));
ipcMain.handle('store:set', (_, key, value) => store.set(key, value));
ipcMain.handle('store:delete', (_, key) => store.delete(key));

// ─── IPC Handlers: Todoist API ───────────────────────────────────────────────
ipcMain.handle('todoist:getProjects', async () => {
  return todoistFetch('/projects');
});

ipcMain.handle('todoist:createProject', async (_, data) => {
  return todoistFetch('/projects', {
    method: 'POST',
    body: JSON.stringify(data)
  });
});

ipcMain.handle('todoist:getTasks', async (_, params) => {
  const query = new URLSearchParams(params).toString();
  return todoistFetch(`/tasks?${query}`);
});

ipcMain.handle('todoist:createTask', async (_, data) => {
  return todoistFetch('/tasks', {
    method: 'POST',
    body: JSON.stringify(data)
  });
});

ipcMain.handle('todoist:updateTask', async (_, id, data) => {
  return todoistFetch(`/tasks/${id}`, {
    method: 'POST',
    body: JSON.stringify(data)
  });
});

ipcMain.handle('todoist:closeTask', async (_, id) => {
  return todoistFetch(`/tasks/${id}/close`, {
    method: 'POST'
  });
});

ipcMain.handle('todoist:deleteTask', async (_, id) => {
  return todoistFetch(`/tasks/${id}`, {
    method: 'DELETE'
  });
});

ipcMain.handle('todoist:getLabels', async () => {
  return todoistFetch('/labels');
});

ipcMain.handle('todoist:createLabel', async (_, data) => {
  return todoistFetch('/labels', {
    method: 'POST',
    body: JSON.stringify(data)
  });
});

ipcMain.handle('todoist:getSections', async (_, params) => {
  const query = new URLSearchParams(params).toString();
  return todoistFetch(`/sections?${query}`);
});

// ─── App Lifecycle ───────────────────────────────────────────────────────────
app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

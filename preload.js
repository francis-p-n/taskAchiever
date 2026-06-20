const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  // Window controls
  minimize: () => ipcRenderer.invoke('window:minimize'),
  maximize: () => ipcRenderer.invoke('window:maximize'),
  close: () => ipcRenderer.invoke('window:close'),
  isMaximized: () => ipcRenderer.invoke('window:isMaximized'),

  // Store
  storeGet: (key) => ipcRenderer.invoke('store:get', key),
  storeSet: (key, value) => ipcRenderer.invoke('store:set', key, value),
  storeDelete: (key) => ipcRenderer.invoke('store:delete', key),

  // Todoist API
  todoist: {
    getProjects: () => ipcRenderer.invoke('todoist:getProjects'),
    createProject: (data) => ipcRenderer.invoke('todoist:createProject', data),
    getTasks: (params) => ipcRenderer.invoke('todoist:getTasks', params),
    createTask: (data) => ipcRenderer.invoke('todoist:createTask', data),
    updateTask: (id, data) => ipcRenderer.invoke('todoist:updateTask', id, data),
    closeTask: (id) => ipcRenderer.invoke('todoist:closeTask', id),
    deleteTask: (id) => ipcRenderer.invoke('todoist:deleteTask', id),
    getLabels: () => ipcRenderer.invoke('todoist:getLabels'),
    createLabel: (data) => ipcRenderer.invoke('todoist:createLabel', data),
    getSections: (params) => ipcRenderer.invoke('todoist:getSections', params)
  }
});

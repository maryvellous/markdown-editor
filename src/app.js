(() => {
  'use strict';

  const invoke = window.__TAURI__?.core?.invoke;

  const editor = document.getElementById('editor');
  const preview = document.getElementById('preview');
  const workspace = document.getElementById('workspace');
  const fileName = document.getElementById('fileName');
  const filePath = document.getElementById('filePath');
  const dirtyDot = document.getElementById('dirtyDot');
  const saveState = document.getElementById('saveState');
  const wordCount = document.getElementById('wordCount');
  const charCount = document.getElementById('charCount');
  const toast = document.getElementById('toast');

  const state = {
    path: null,
    name: 'Senza titolo.md',
    savedContent: '',
    mode: 'split',
    renderVersion: 0,
    renderTimer: null,
    toastTimer: null,
  };

  function requireTauri() {
    if (!invoke) {
      showToast('API desktop non disponibile. Avvia l’app tramite Tauri.', true);
      return false;
    }
    return true;
  }

  function isDirty() {
    return editor.value !== state.savedContent;
  }

  function showToast(message, isError = false) {
    window.clearTimeout(state.toastTimer);
    toast.textContent = message;
    toast.classList.toggle('is-error', isError);
    toast.classList.add('is-visible');
    state.toastTimer = window.setTimeout(() => toast.classList.remove('is-visible'), 2600);
  }

  function updateDocumentMeta() {
    const dirty = isDirty();
    fileName.textContent = state.name;
    filePath.textContent = state.path || 'Nuovo documento';
    dirtyDot.classList.toggle('is-dirty', dirty);
    saveState.textContent = dirty ? 'Modifiche non salvate' : 'Salvato';
    saveState.classList.toggle('status-dirty', dirty);
    saveState.classList.toggle('status-saved', !dirty);
    document.title = `${dirty ? '• ' : ''}${state.name} — Diaspro Markdown`;
  }

  function updateCounts() {
    const text = editor.value;
    const words = text.trim() ? text.trim().split(/\s+/u).length : 0;
    wordCount.textContent = `${words} ${words === 1 ? 'parola' : 'parole'}`;
    charCount.textContent = `${text.length} ${text.length === 1 ? 'carattere' : 'caratteri'}`;
  }

  function renderEmptyPreview() {
    preview.innerHTML = `
      <div class="empty-preview">
        <div class="empty-mark">m</div>
        <p>L'anteprima comparirà qui mentre scrivi.</p>
      </div>`;
  }

  async function refreshPreview() {
    updateCounts();
    updateDocumentMeta();

    const markdown = editor.value;
    if (!markdown.trim()) {
      state.renderVersion += 1;
      renderEmptyPreview();
      return;
    }

    if (!requireTauri()) return;

    const version = ++state.renderVersion;
    try {
      const html = await invoke('render_markdown', { markdown });
      if (version !== state.renderVersion) return;
      preview.innerHTML = html;
    } catch (error) {
      if (version !== state.renderVersion) return;
      preview.textContent = `Errore anteprima: ${String(error)}`;
    }
  }

  function schedulePreview() {
    window.clearTimeout(state.renderTimer);
    state.renderTimer = window.setTimeout(refreshPreview, 90);
  }

  function loadDocument(documentData) {
    if (!documentData) return;
    state.path = documentData.path || null;
    state.name = documentData.name || 'documento.md';
    state.savedContent = documentData.content || '';
    editor.value = state.savedContent;
    editor.scrollTop = 0;
    preview.scrollTop = 0;
    refreshPreview();
  }

  function confirmDiscardIfNeeded() {
    if (!isDirty()) return true;
    return window.confirm('Ci sono modifiche non salvate. Vuoi scartarle?');
  }

  function newDocument() {
    if (!confirmDiscardIfNeeded()) return;
    state.path = null;
    state.name = 'Senza titolo.md';
    state.savedContent = '';
    editor.value = '';
    refreshPreview();
    editor.focus();
  }

  async function openDocument() {
    if (!confirmDiscardIfNeeded() || !requireTauri()) return;
    try {
      const result = await invoke('open_document');
      if (result) loadDocument(result);
    } catch (error) {
      showToast(String(error), true);
    }
  }

  async function saveAs() {
    if (!requireTauri()) return false;
    try {
      const suggestedName = state.path ? state.name : 'documento.md';
      const result = await invoke('save_document_as', {
        content: editor.value,
        suggestedName,
      });
      if (!result) return false;
      loadDocument(result);
      showToast('File salvato.');
      return true;
    } catch (error) {
      showToast(String(error), true);
      return false;
    }
  }

  async function saveDocument() {
    if (!requireTauri()) return false;
    if (!state.path) return saveAs();

    try {
      const result = await invoke('save_document', {
        path: state.path,
        content: editor.value,
      });
      loadDocument(result);
      showToast('Salvato.');
      return true;
    } catch (error) {
      showToast(String(error), true);
      return false;
    }
  }

  function setMode(mode) {
    if (!['edit', 'split', 'preview'].includes(mode)) return;
    state.mode = mode;
    workspace.classList.remove('mode-edit', 'mode-split', 'mode-preview');
    workspace.classList.add(`mode-${mode}`);
    document.querySelectorAll('.mode-button').forEach((button) => {
      button.classList.toggle('is-active', button.dataset.mode === mode);
    });
    if (mode !== 'preview') editor.focus();
  }

  async function loadStartupDocument() {
    if (!requireTauri()) return;
    try {
      const result = await invoke('startup_document');
      if (result) loadDocument(result);
      else refreshPreview();
    } catch (error) {
      showToast(String(error), true);
      refreshPreview();
    }
  }

  editor.addEventListener('input', schedulePreview);
  editor.addEventListener('keydown', (event) => {
    if (event.key === 'Tab') {
      event.preventDefault();
      const start = editor.selectionStart;
      const end = editor.selectionEnd;
      editor.setRangeText('  ', start, end, 'end');
      schedulePreview();
    }
  });

  document.getElementById('newBtn').addEventListener('click', newDocument);
  document.getElementById('openBtn').addEventListener('click', openDocument);
  document.getElementById('saveBtn').addEventListener('click', saveDocument);
  document.getElementById('saveAsBtn').addEventListener('click', saveAs);

  document.querySelectorAll('.mode-button').forEach((button) => {
    button.addEventListener('click', () => setMode(button.dataset.mode));
  });

  document.addEventListener('keydown', (event) => {
    if (!(event.ctrlKey || event.metaKey)) return;

    const key = event.key.toLowerCase();
    if (key === 's') {
      event.preventDefault();
      if (event.shiftKey) saveAs();
      else saveDocument();
    } else if (key === 'o') {
      event.preventDefault();
      openDocument();
    } else if (key === 'n') {
      event.preventDefault();
      newDocument();
    }
  });

  preview.addEventListener('click', (event) => {
    const link = event.target.closest('a');
    if (!link) return;
    event.preventDefault();
    showToast(`Link: ${link.getAttribute('href') || ''}`);
  });

  loadStartupDocument();
})();

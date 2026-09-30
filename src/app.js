(() => {
  'use strict';

  const invoke = window.__TAURI__?.core?.invoke;
  const RECENTS_KEY = 'diaspro-markdown.recents.v1';
  const SIDEBAR_KEY = 'diaspro-markdown.sidebar-open.v1';
  const MAX_RECENTS = 8;
  const TICK = String.fromCharCode(96);
  const FENCE = TICK.repeat(3);

  const editor = document.getElementById('editor');
  const preview = document.getElementById('preview');
  const workspace = document.getElementById('workspace');
  const contentRow = document.getElementById('contentRow');
  const sideToggleBtn = document.getElementById('sideToggleBtn');
  const closeSideBtn = document.getElementById('closeSideBtn');
  const recentList = document.getElementById('recentList');
  const recentEmpty = document.getElementById('recentEmpty');
  const clearRecentBtn = document.getElementById('clearRecentBtn');
  const markdownGuide = document.getElementById('markdownGuide');
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
    sidebarOpen: readStoredSidebarState(),
    renderVersion: 0,
    renderTimer: null,
    previewDirty: true,
    toastTimer: null,
  };

  const GUIDE_ITEMS = [
    { label: 'Titolo', syntax: '# … ######', type: 'prefix', value: '# ', placeholder: 'Titolo' },
    { label: 'Grassetto', syntax: '**testo**', type: 'wrap', before: '**', after: '**', placeholder: 'testo' },
    { label: 'Corsivo', syntax: '*testo*', type: 'wrap', before: '*', after: '*', placeholder: 'testo' },
    { label: 'Grassetto + corsivo', syntax: '***testo***', type: 'wrap', before: '***', after: '***', placeholder: 'testo' },
    { label: 'Barrato', syntax: '~~testo~~', type: 'wrap', before: '~~', after: '~~', placeholder: 'testo' },
    { label: 'Codice inline', syntax: TICK + 'codice' + TICK, type: 'wrap', before: TICK, after: TICK, placeholder: 'codice' },
    { label: 'Blocco codice', syntax: FENCE, type: 'snippet', value: FENCE + '\nlinguaggio\ncodice\n' + FENCE, selectText: 'codice' },
    { label: 'Citazione', syntax: '> testo', type: 'prefix', value: '> ', placeholder: 'testo' },
    { label: 'Elenco puntato', syntax: '- voce', type: 'prefix', value: '- ', placeholder: 'voce' },
    { label: 'Elenco numerato', syntax: '1. voce', type: 'prefix', value: '1. ', placeholder: 'voce' },
    { label: 'Checkbox', syntax: '- [ ] attività', type: 'prefix', value: '- [ ] ', placeholder: 'attività' },
    { label: 'Link', syntax: '[testo](url)', type: 'snippet', value: '[testo](https://)', selectText: 'testo' },
    { label: 'Immagine', syntax: '![alt](file.png)', type: 'snippet', value: '![descrizione](immagine.png)', selectText: 'descrizione' },
    { label: 'Separatore', syntax: '---', type: 'snippet', value: '\n---\n' },
    { label: 'Tabella', syntax: '| A | B |', type: 'snippet', value: '| Colonna A | Colonna B |\n| --- | --- |\n| Valore | Valore |' },
    { label: 'Nota a piè pagina', syntax: '[^1]', type: 'snippet', value: 'Testo[^1]\n\n[^1]: Nota', selectText: 'Nota' },
    { label: 'A capo forzato', syntax: '2 spazi + Invio', type: 'snippet', value: '  \n' },
    { label: 'Escape', syntax: '\\*testo\\*', type: 'snippet', value: '\\*testo\\*', selectText: 'testo' },
  ];

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
    document.title = (dirty ? '• ' : '') + state.name + ' — Diaspro Markdown';
  }

  function updateCounts() {
    const text = editor.value;
    const words = text.trim() ? text.trim().split(/\s+/u).length : 0;
    wordCount.textContent = words + ' ' + (words === 1 ? 'parola' : 'parole');
    charCount.textContent = text.length + ' ' + (text.length === 1 ? 'carattere' : 'caratteri');
  }

  function renderEmptyPreview() {
    preview.innerHTML =
      '<div class="empty-preview">' +
        '<div class="empty-mark">m</div>' +
        '<p>L’anteprima comparirà qui mentre scrivi.</p>' +
      '</div>';
  }

  async function refreshPreview() {
    window.clearTimeout(state.renderTimer);
    updateCounts();
    updateDocumentMeta();
    state.previewDirty = false;

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
      preview.textContent = 'Errore anteprima: ' + String(error);
    }
  }

  function schedulePreview() {
    state.previewDirty = true;
    updateCounts();
    updateDocumentMeta();

    window.clearTimeout(state.renderTimer);
    if (state.mode === 'edit') return;

    state.renderTimer = window.setTimeout(refreshPreview, 120);
  }

  function loadDocument(documentData) {
    if (!documentData) return;
    state.path = documentData.path || null;
    state.name = documentData.name || 'documento.md';
    state.savedContent = documentData.content || '';
    editor.value = state.savedContent;
    editor.scrollTop = 0;
    preview.scrollTop = 0;
    addRecent(documentData);
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

  async function openRecent(path) {
    if (!confirmDiscardIfNeeded() || !requireTauri()) return;

    try {
      const result = await invoke('open_document_path', { path });
      loadDocument(result);
    } catch (error) {
      removeRecent(path);
      showToast('File recente non disponibile. È stato rimosso dall’elenco.', true);
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
    workspace.classList.add('mode-' + mode);
    document.querySelectorAll('.mode-button').forEach((button) => {
      button.classList.toggle('is-active', button.dataset.mode === mode);
    });

    if (mode !== 'edit' && state.previewDirty) refreshPreview();
    if (mode !== 'preview') editor.focus();
  }

  function readStoredSidebarState() {
    try {
      return window.localStorage.getItem(SIDEBAR_KEY) !== '0';
    } catch {
      return true;
    }
  }

  function setSidebarOpen(open) {
    state.sidebarOpen = Boolean(open);
    contentRow.classList.toggle('sidebar-closed', !state.sidebarOpen);
    sideToggleBtn.textContent = state.sidebarOpen ? 'Nascondi guida' : 'Guida';
    sideToggleBtn.setAttribute('aria-pressed', state.sidebarOpen ? 'true' : 'false');

    try {
      window.localStorage.setItem(SIDEBAR_KEY, state.sidebarOpen ? '1' : '0');
    } catch {
      // Lo storage non è essenziale per il funzionamento della UI.
    }
  }

  function getRecents() {
    try {
      const parsed = JSON.parse(window.localStorage.getItem(RECENTS_KEY) || '[]');
      if (!Array.isArray(parsed)) return [];
      return parsed
        .filter((item) => item && typeof item.path === 'string' && typeof item.name === 'string')
        .slice(0, MAX_RECENTS);
    } catch {
      return [];
    }
  }

  function storeRecents(items) {
    const clean = items.slice(0, MAX_RECENTS);
    try {
      window.localStorage.setItem(RECENTS_KEY, JSON.stringify(clean));
    } catch {
      // Se localStorage non è disponibile, l’app continua semplicemente senza cronologia.
    }
    renderRecents(clean);
  }

  function normalizeRecentPath(path) {
    return String(path || '').toLocaleLowerCase();
  }

  function addRecent(documentData) {
    if (!documentData || !documentData.path) return;
    const target = normalizeRecentPath(documentData.path);
    const next = getRecents().filter((item) => normalizeRecentPath(item.path) !== target);
    next.unshift({ path: documentData.path, name: documentData.name || 'documento.md' });
    storeRecents(next);
  }

  function removeRecent(path) {
    const target = normalizeRecentPath(path);
    storeRecents(getRecents().filter((item) => normalizeRecentPath(item.path) !== target));
  }

  function renderRecents(items = getRecents()) {
    recentList.replaceChildren();
    recentEmpty.hidden = items.length > 0;
    clearRecentBtn.disabled = items.length === 0;

    items.forEach((item) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'recent-item';
      button.title = item.path;

      const name = document.createElement('span');
      name.className = 'recent-name';
      name.textContent = item.name;

      const path = document.createElement('span');
      path.className = 'recent-path';
      path.textContent = item.path;

      button.append(name, path);
      button.addEventListener('click', () => openRecent(item.path));
      recentList.appendChild(button);
    });
  }

  function renderGuide() {
    markdownGuide.replaceChildren();

    GUIDE_ITEMS.forEach((item) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'guide-item';
      button.title = 'Inserisci: ' + item.label;

      const label = document.createElement('span');
      label.className = 'guide-label';
      label.textContent = item.label;

      const syntax = document.createElement('code');
      syntax.className = 'guide-syntax';
      syntax.textContent = item.syntax;

      button.append(label, syntax);
      button.addEventListener('click', () => insertGuideItem(item));
      markdownGuide.appendChild(button);
    });
  }

  function insertGuideItem(item) {
    setMode('edit');
    editor.focus();

    const start = editor.selectionStart;
    const end = editor.selectionEnd;
    const selected = editor.value.slice(start, end);
    let insertion = '';
    let selectionStart = null;
    let selectionEnd = null;

    if (item.type === 'wrap') {
      const body = selected || item.placeholder || 'testo';
      insertion = item.before + body + item.after;
      if (!selected) {
        selectionStart = start + item.before.length;
        selectionEnd = selectionStart + body.length;
      }
    } else if (item.type === 'prefix') {
      if (selected) {
        insertion = selected
          .split('\n')
          .map((line) => item.value + line)
          .join('\n');
      } else {
        const body = item.placeholder || 'testo';
        insertion = item.value + body;
        selectionStart = start + item.value.length;
        selectionEnd = selectionStart + body.length;
      }
    } else {
      insertion = item.value || '';
      if (item.selectText) {
        const offset = insertion.indexOf(item.selectText);
        if (offset >= 0) {
          selectionStart = start + offset;
          selectionEnd = selectionStart + item.selectText.length;
        }
      }
    }

    editor.setRangeText(insertion, start, end, 'end');

    if (selectionStart !== null && selectionEnd !== null) {
      editor.setSelectionRange(selectionStart, selectionEnd);
    }

    schedulePreview();
  }

  async function loadStartupDocument() {
    renderGuide();
    renderRecents();
    setSidebarOpen(state.sidebarOpen);

    if (!requireTauri()) {
      refreshPreview();
      return;
    }

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
  sideToggleBtn.addEventListener('click', () => setSidebarOpen(!state.sidebarOpen));
  closeSideBtn.addEventListener('click', () => setSidebarOpen(false));
  clearRecentBtn.addEventListener('click', () => storeRecents([]));

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
    showToast('Link: ' + (link.getAttribute('href') || ''));
  });

  loadStartupDocument();
})();

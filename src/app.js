import { createEditorHistory } from './editor-history.mjs';
import { createMermaidRenderer } from './mermaid-renderer.mjs';
import { createMermaidViewer } from './mermaid-viewer.mjs';
import { createRecentDocuments } from './recent-documents.mjs';
import { createMarkdownGuide } from './markdown-guide.mjs';
import { createDocumentController } from './document-controller.mjs';

(() => {
  'use strict';

  const invoke = window.__TAURI__?.core?.invoke;
  const tauriWindow = window.__TAURI__?.window;
  const appWindow = tauriWindow?.getCurrentWindow ? tauriWindow.getCurrentWindow() : null;
  const ACTIVE_PANEL_KEY = 'diaspro-markdown.active-panel.v2';

  const editor = document.getElementById('editor');
  const preview = document.getElementById('preview');
  const workspace = document.getElementById('workspace');
  const contentRow = document.getElementById('contentRow');
  const sidePanel = document.getElementById('sidePanel');
  const recentPanelBtn = document.getElementById('recentPanelBtn');
  const guidePanelBtn = document.getElementById('guidePanelBtn');
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
  const undoBtn = document.getElementById('undoBtn');
  const redoBtn = document.getElementById('redoBtn');
  const mermaidViewer = document.getElementById('mermaidViewer');
  const mermaidViewerCanvas = document.getElementById('mermaidViewerCanvas');
  const mermaidViewerContent = document.getElementById('mermaidViewerContent');
  const mermaidZoomOutBtn = document.getElementById('mermaidZoomOutBtn');
  const mermaidZoomResetBtn = document.getElementById('mermaidZoomResetBtn');
  const mermaidZoomInBtn = document.getElementById('mermaidZoomInBtn');
  const mermaidFitBtn = document.getElementById('mermaidFitBtn');
  const mermaidCloseBtn = document.getElementById('mermaidCloseBtn');

  const state = {
    path: null,
    name: 'Senza titolo.md',
    savedContent: '',
    savedFileContent: '',
    mode: 'split',
    activePanel: readStoredPanelState(),
    renderVersion: 0,
    renderTimer: null,
    previewDirty: true,
    toastTimer: null,
    documentBusy: false,
  };

  const { resetHistory, commitHistory, undoEditor, redoEditor } =
    createEditorHistory({ editor, undoBtn, redoBtn, schedulePreview });
  const { renderMermaidBlocks } = createMermaidRenderer({
    preview, isCurrent: (version) => version === state.renderVersion,
  });
  const { openMermaidViewer, closeMermaidViewer, setupMermaidViewer } =
    createMermaidViewer({
      mermaidViewer, mermaidViewerCanvas, mermaidViewerContent, mermaidZoomOutBtn,
      mermaidZoomResetBtn, mermaidZoomInBtn, mermaidFitBtn, mermaidCloseBtn,
    });
  const { addRecent, removeRecent, renderRecents, storeRecents } =
    createRecentDocuments({
      recentList, recentEmpty, clearRecentBtn, openRecent: (path) => openRecent(path),
    });
  const { isDirty, confirmDiscardIfNeeded, newDocument, openDocument, openRecent,
    saveDocument, saveAs, loadStartupDocument } = createDocumentController({
      editor, preview, state, invoke, requireTauri, showToast,
      addRecent, removeRecent, resetHistory, refreshPreview,
    });
  const { renderGuide } = createMarkdownGuide({
    editor, markdownGuide, getMode: () => state.mode, setMode, commitHistory, schedulePreview,
  });

  function setupWindowControls() {
    const minimizeBtn = document.getElementById('windowMinimizeBtn');
    const maximizeBtn = document.getElementById('windowMaximizeBtn');
    const closeBtn = document.getElementById('windowCloseBtn');
    const titlebar = document.getElementById('windowTitlebar');

    if (!appWindow || !minimizeBtn || !maximizeBtn || !closeBtn || !titlebar) return;

    minimizeBtn.addEventListener('click', () => appWindow.minimize());
    maximizeBtn.addEventListener('click', () => appWindow.toggleMaximize());
    // All ordinary close requests (including Alt+F4) use the same guard.
    let closeGuardReady = false;
    appWindow.onCloseRequested((event) => {
      if (state.documentBusy || !confirmDiscardIfNeeded()) event.preventDefault();
    }).then(() => { closeGuardReady = true; }).catch((error) => {
      showToast('Protezione chiusura non disponibile: ' + String(error), true);
    });
    closeBtn.addEventListener('click', () => {
      if (state.documentBusy) return;
      if (closeGuardReady || confirmDiscardIfNeeded()) {
        appWindow.close().catch((error) => showToast(String(error), true));
      }
    });

    titlebar.addEventListener('dblclick', (event) => {
      if (event.target.closest('.window-controls')) return;
      appWindow.toggleMaximize();
    });
  }

  function requireTauri() {
    if (!invoke) {
      showToast('API desktop non disponibile. Avvia l’app tramite Tauri.', true);
      return false;
    }
    return true;
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
        '<img class="empty-mark" src="./assets/app_icon.png" alt="" aria-hidden="true" />' +
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
      await renderMermaidBlocks(version);
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

  function readStoredPanelState() {
    try {
      const value = window.localStorage.getItem(ACTIVE_PANEL_KEY);
      return ['recent', 'guide'].includes(value) ? value : null;
    } catch {
      return null;
    }
  }

  function setActivePanel(panel) {
    const nextPanel = ['recent', 'guide'].includes(panel) ? panel : null;
    state.activePanel = nextPanel;

    contentRow.classList.toggle('panel-open', Boolean(nextPanel));
    sidePanel.setAttribute('aria-hidden', nextPanel ? 'false' : 'true');

    [recentPanelBtn, guidePanelBtn].forEach((button) => {
      const active = button.dataset.panel === nextPanel;
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-pressed', active ? 'true' : 'false');
    });

    document.querySelectorAll('[data-tool-panel]').forEach((panelElement) => {
      panelElement.hidden = panelElement.dataset.toolPanel !== nextPanel;
    });

    try {
      if (nextPanel) window.localStorage.setItem(ACTIVE_PANEL_KEY, nextPanel);
      else window.localStorage.removeItem(ACTIVE_PANEL_KEY);
    } catch {
      // Lo stato del pannello non è essenziale al funzionamento.
    }
  }

  function togglePanel(panel) {
    setActivePanel(state.activePanel === panel ? null : panel);
  }

  editor.addEventListener('beforeinput', (event) => {
    if (event.inputType === 'historyUndo') {
      event.preventDefault();
      undoEditor();
    } else if (event.inputType === 'historyRedo') {
      event.preventDefault();
      redoEditor();
    }
  });

  editor.addEventListener('input', (event) => {
    const kind = ['insertText', 'deleteContentBackward', 'deleteContentForward'].includes(event.inputType)
      ? 'typing'
      : (event.inputType || 'edit');
    commitHistory(kind);
    schedulePreview();
  });

  editor.addEventListener('keydown', (event) => {
    if (event.key === 'Tab') {
      event.preventDefault();
      const start = editor.selectionStart;
      const end = editor.selectionEnd;
      editor.setRangeText('  ', start, end, 'end');
      commitHistory('tab');
      schedulePreview();
    }
  });

  document.getElementById('newBtn').addEventListener('click', newDocument);
  document.getElementById('openBtn').addEventListener('click', openDocument);
  document.getElementById('saveBtn').addEventListener('click', saveDocument);
  document.getElementById('saveAsBtn').addEventListener('click', saveAs);
  undoBtn.addEventListener('click', undoEditor);
  redoBtn.addEventListener('click', redoEditor);

  recentPanelBtn.addEventListener('click', () => togglePanel('recent'));
  guidePanelBtn.addEventListener('click', () => togglePanel('guide'));
  document.querySelectorAll('.close-panel-btn').forEach((button) => {
    button.addEventListener('click', () => setActivePanel(null));
  });
  clearRecentBtn.addEventListener('click', () => storeRecents([]));

  document.querySelectorAll('.mode-button').forEach((button) => {
    button.addEventListener('click', () => setMode(button.dataset.mode));
  });

  document.addEventListener('keydown', (event) => {
    if (!(event.ctrlKey || event.metaKey)) return;
    if (!mermaidViewer.hidden) return;

    const key = event.key.toLowerCase();
    if (key === 'z') {
      event.preventDefault();
      if (event.shiftKey) redoEditor();
      else undoEditor();
    } else if (key === 'y') {
      event.preventDefault();
      redoEditor();
    } else if (key === 's') {
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
    const viewerButton = event.target.closest('[data-mermaid-viewer]');
    if (viewerButton) {
      const block = viewerButton.closest('.mermaid-block');
      openMermaidViewer(block?.__diasproMermaidSvg || '');
      return;
    }

    const link = event.target.closest('a');
    if (!link) return;
    event.preventDefault();
    showToast('Link: ' + (link.getAttribute('href') || ''));
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !mermaidViewer.hidden) {
      event.preventDefault();
      closeMermaidViewer();
    }
  });

  setupWindowControls();
  setupMermaidViewer();
  renderGuide();
  renderRecents();
  setActivePanel(state.activePanel);
  loadStartupDocument();
})();

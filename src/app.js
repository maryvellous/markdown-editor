(() => {
  'use strict';

  const invoke = window.__TAURI__?.core?.invoke;
  const tauriWindow = window.__TAURI__?.window;
  const appWindow = tauriWindow?.getCurrentWindow ? tauriWindow.getCurrentWindow() : null;
  const RECENTS_KEY = 'diaspro-markdown.recents.v1';
  const ACTIVE_PANEL_KEY = 'diaspro-markdown.active-panel.v2';
  const MAX_RECENTS = 8;
  const TICK = String.fromCharCode(96);
  const FENCE = TICK.repeat(3);

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
    mode: 'split',
    activePanel: readStoredPanelState(),
    renderVersion: 0,
    renderTimer: null,
    previewDirty: true,
    toastTimer: null,
    history: [],
    historyIndex: -1,
    historyLastKind: null,
    historyLastAt: 0,
    applyingHistory: false,
  };

  const MERMAID_CACHE_LIMIT = 24;
  const mermaidCache = new Map();
  let mermaidInitialized = false;
  let mermaidRenderSequence = 0;
  const viewerState = {
    svg: '',
    scale: 1,
    x: 0,
    y: 0,
    naturalWidth: 0,
    naturalHeight: 0,
    dragging: false,
    pointerId: null,
    startPointerX: 0,
    startPointerY: 0,
    startX: 0,
    startY: 0,
  };

  const GUIDE_ITEMS = [
    { label: 'Titolo', syntax: '# … ######', type: 'prefix', value: '# ', placeholder: 'Titolo' },
    { label: 'Grassetto', syntax: '**testo**', type: 'wrap', before: '**', after: '**', placeholder: 'testo' },
    { label: 'Corsivo', syntax: '*testo*', type: 'wrap', before: '*', after: '*', placeholder: 'testo' },
    { label: 'Grassetto + corsivo', syntax: '***testo***', type: 'wrap', before: '***', after: '***', placeholder: 'testo' },
    { label: 'Barrato', syntax: '~~testo~~', type: 'wrap', before: '~~', after: '~~', placeholder: 'testo' },
    { label: 'Codice inline', syntax: TICK + 'codice' + TICK, type: 'wrap', before: TICK, after: TICK, placeholder: 'codice' },
    { label: 'Blocco codice', syntax: FENCE, type: 'snippet', value: FENCE + '\nlinguaggio\ncodice\n' + FENCE, selectText: 'codice' },
    { label: 'Diagramma Mermaid', syntax: FENCE + 'mermaid', type: 'snippet', value: FENCE + 'mermaid\ngraph TD\n  A[Inizio] --> B[Fine]\n' + FENCE, selectText: 'graph TD\n  A[Inizio] --> B[Fine]' },
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

  function setupWindowControls() {
    const minimizeBtn = document.getElementById('windowMinimizeBtn');
    const maximizeBtn = document.getElementById('windowMaximizeBtn');
    const closeBtn = document.getElementById('windowCloseBtn');
    const titlebar = document.getElementById('windowTitlebar');

    if (!appWindow || !minimizeBtn || !maximizeBtn || !closeBtn || !titlebar) return;

    minimizeBtn.addEventListener('click', () => appWindow.minimize());
    maximizeBtn.addEventListener('click', () => appWindow.toggleMaximize());
    closeBtn.addEventListener('click', () => {
      if (confirmDiscardIfNeeded()) appWindow.close();
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

  function currentEditorSnapshot() {
    return {
      value: editor.value,
      selectionStart: editor.selectionStart,
      selectionEnd: editor.selectionEnd,
    };
  }

  function sameSnapshot(a, b) {
    return Boolean(
      a &&
      b &&
      a.value === b.value &&
      a.selectionStart === b.selectionStart &&
      a.selectionEnd === b.selectionEnd,
    );
  }

  function updateHistoryControls() {
    undoBtn.disabled = state.historyIndex <= 0;
    redoBtn.disabled = state.historyIndex < 0 || state.historyIndex >= state.history.length - 1;
  }

  function resetHistory() {
    state.history = [currentEditorSnapshot()];
    state.historyIndex = 0;
    state.historyLastKind = null;
    state.historyLastAt = 0;
    updateHistoryControls();
  }

  function commitHistory(kind = 'edit') {
    if (state.applyingHistory) return;

    const snapshot = currentEditorSnapshot();
    const current = state.history[state.historyIndex];
    if (sameSnapshot(snapshot, current)) {
      updateHistoryControls();
      return;
    }

    if (state.historyIndex < state.history.length - 1) {
      state.history = state.history.slice(0, state.historyIndex + 1);
    }

    const now = Date.now();
    const coalesce =
      kind === 'typing' &&
      state.historyLastKind === 'typing' &&
      now - state.historyLastAt < 700 &&
      state.historyIndex === state.history.length - 1 &&
      state.historyIndex > 0;

    if (coalesce) {
      state.history[state.historyIndex] = snapshot;
    } else {
      state.history.push(snapshot);
      state.historyIndex = state.history.length - 1;

      if (state.history.length > 120) {
        state.history.shift();
        state.historyIndex -= 1;
      }
    }

    state.historyLastKind = kind;
    state.historyLastAt = now;
    updateHistoryControls();
  }

  function applyHistorySnapshot(snapshot) {
    if (!snapshot) return;
    state.applyingHistory = true;
    editor.value = snapshot.value;
    editor.setSelectionRange(snapshot.selectionStart, snapshot.selectionEnd);
    state.applyingHistory = false;
    state.historyLastKind = null;
    state.historyLastAt = 0;
    schedulePreview();
    editor.focus();
    updateHistoryControls();
  }

  function undoEditor() {
    if (state.historyIndex <= 0) return;
    state.historyIndex -= 1;
    applyHistorySnapshot(state.history[state.historyIndex]);
  }

  function redoEditor() {
    if (state.historyIndex >= state.history.length - 1) return;
    state.historyIndex += 1;
    applyHistorySnapshot(state.history[state.historyIndex]);
  }

  function renderEmptyPreview() {
    preview.innerHTML =
      '<div class="empty-preview">' +
        '<img class="empty-mark" src="./assets/app_icon.png" alt="" aria-hidden="true" />' +
        '<p>L’anteprima comparirà qui mentre scrivi.</p>' +
      '</div>';
  }


  function ensureMermaidInitialized() {
    if (mermaidInitialized) return true;
    if (!window.mermaid) return false;

    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      theme: 'base',
      suppressErrorRendering: true,
      themeVariables: {
        primaryColor: '#f4ecd9',
        primaryTextColor: '#2b1c47',
        primaryBorderColor: '#7a3f67',
        lineColor: '#7a3f67',
        secondaryColor: '#e8d19e',
        tertiaryColor: '#a5c4dc',
        background: '#fffdf8',
        mainBkg: '#fffdf8',
        nodeBorder: '#7a3f67',
        clusterBkg: '#f4ecd9',
        clusterBorder: '#9d85c6',
        edgeLabelBackground: '#fffdf8',
        fontFamily: 'Inter, Segoe UI, system-ui, sans-serif',
      },
      flowchart: {
        htmlLabels: false,
        useMaxWidth: true,
      },
    });
    mermaidInitialized = true;
    return true;
  }

  function readCachedMermaid(source) {
    if (!mermaidCache.has(source)) return null;
    const svg = mermaidCache.get(source);
    mermaidCache.delete(source);
    mermaidCache.set(source, svg);
    return svg;
  }

  function cacheMermaid(source, svg) {
    mermaidCache.delete(source);
    mermaidCache.set(source, svg);
    while (mermaidCache.size > MERMAID_CACHE_LIMIT) {
      const firstKey = mermaidCache.keys().next().value;
      mermaidCache.delete(firstKey);
    }
  }

  function buildMermaidBlock(svg, source) {
    const block = document.createElement('section');
    block.className = 'mermaid-block';

    const head = document.createElement('div');
    head.className = 'mermaid-block-head';

    const title = document.createElement('span');
    title.className = 'mermaid-block-title';
    title.textContent = 'Diagramma Mermaid';

    const openButton = document.createElement('button');
    openButton.type = 'button';
    openButton.className = 'mermaid-open-button';
    openButton.textContent = 'Apri grande';
    openButton.title = 'Apri il diagramma nel viewer';
    openButton.dataset.mermaidViewer = 'true';

    const diagram = document.createElement('div');
    diagram.className = 'mermaid-diagram';
    diagram.innerHTML = svg;

    block.dataset.mermaidSource = source;
    block.dataset.mermaidSvg = svg;
    head.append(title, openButton);
    block.append(head, diagram);
    return block;
  }

  function buildMermaidError(source, error) {
    const block = document.createElement('section');
    block.className = 'mermaid-block mermaid-block-error';

    const errorBox = document.createElement('div');
    errorBox.className = 'mermaid-error';

    const title = document.createElement('strong');
    title.textContent = 'Diagramma Mermaid non valido';

    const message = document.createElement('div');
    message.textContent = String(error || 'Errore sconosciuto');

    const raw = document.createElement('pre');
    const code = document.createElement('code');
    code.textContent = source;
    raw.appendChild(code);

    errorBox.append(title, message, raw);
    block.appendChild(errorBox);
    return block;
  }

  async function renderMermaidBlocks(version) {
    const mermaidCodes = Array.from(preview.querySelectorAll('pre > code.language-mermaid'));
    if (mermaidCodes.length === 0) return;

    if (!ensureMermaidInitialized()) {
      mermaidCodes.forEach((code) => {
        const source = code.textContent || '';
        code.parentElement.replaceWith(
          buildMermaidError(source, 'Renderer Mermaid non disponibile.'),
        );
      });
      return;
    }

    for (const code of mermaidCodes) {
      if (version !== state.renderVersion) return;

      const source = code.textContent || '';
      const pre = code.parentElement;
      const cached = readCachedMermaid(source);

      if (cached) {
        pre.replaceWith(buildMermaidBlock(cached, source));
        continue;
      }

      try {
        const id = 'diaspro-mermaid-' + (++mermaidRenderSequence);
        const result = await window.mermaid.render(id, source);
        if (version !== state.renderVersion) return;
        cacheMermaid(source, result.svg);
        pre.replaceWith(buildMermaidBlock(result.svg, source));
      } catch (error) {
        if (version !== state.renderVersion) return;
        pre.replaceWith(buildMermaidError(source, error));
      }
    }
  }

  function getSvgNaturalSize(svgElement) {
    const viewBox = svgElement?.viewBox?.baseVal;
    if (viewBox && viewBox.width > 0 && viewBox.height > 0) {
      return { width: viewBox.width, height: viewBox.height };
    }

    const width = Number.parseFloat(svgElement?.getAttribute('width')) || svgElement?.getBoundingClientRect().width || 900;
    const height = Number.parseFloat(svgElement?.getAttribute('height')) || svgElement?.getBoundingClientRect().height || 600;
    return { width, height };
  }

  function applyViewerTransform() {
    mermaidViewerContent.style.transform =
      'translate(' + viewerState.x + 'px, ' + viewerState.y + 'px) scale(' + viewerState.scale + ')';
    mermaidZoomResetBtn.textContent = Math.round(viewerState.scale * 100) + '%';
  }

  function centerViewerAtScale(scale) {
    const canvasRect = mermaidViewerCanvas.getBoundingClientRect();
    viewerState.scale = Math.max(0.15, Math.min(8, scale));
    viewerState.x = (canvasRect.width - viewerState.naturalWidth * viewerState.scale) / 2;
    viewerState.y = (canvasRect.height - viewerState.naturalHeight * viewerState.scale) / 2;
    applyViewerTransform();
  }

  function fitMermaidViewer() {
    if (!viewerState.naturalWidth || !viewerState.naturalHeight) return;
    const canvasRect = mermaidViewerCanvas.getBoundingClientRect();
    const padding = 56;
    const fitScale = Math.min(
      (canvasRect.width - padding) / viewerState.naturalWidth,
      (canvasRect.height - padding) / viewerState.naturalHeight,
    );
    centerViewerAtScale(Math.max(0.15, Math.min(4, fitScale)));
  }

  function setViewerScale(nextScale) {
    const canvasRect = mermaidViewerCanvas.getBoundingClientRect();
    const centerX = canvasRect.width / 2;
    const centerY = canvasRect.height / 2;
    const oldScale = viewerState.scale || 1;
    const scale = Math.max(0.15, Math.min(8, nextScale));
    const contentX = (centerX - viewerState.x) / oldScale;
    const contentY = (centerY - viewerState.y) / oldScale;

    viewerState.scale = scale;
    viewerState.x = centerX - contentX * scale;
    viewerState.y = centerY - contentY * scale;
    applyViewerTransform();
  }

  function openMermaidViewer(svg) {
    if (!svg) return;
    viewerState.svg = svg;
    mermaidViewerContent.innerHTML = svg;
    mermaidViewer.hidden = false;
    mermaidViewer.setAttribute('aria-hidden', 'false');

    window.requestAnimationFrame(() => {
      const svgElement = mermaidViewerContent.querySelector('svg');
      const size = getSvgNaturalSize(svgElement);
      viewerState.naturalWidth = size.width;
      viewerState.naturalHeight = size.height;
      if (svgElement) {
        svgElement.style.width = size.width + 'px';
        svgElement.style.height = size.height + 'px';
      }
      fitMermaidViewer();
      mermaidCloseBtn.focus();
    });
  }

  function closeMermaidViewer() {
    mermaidViewer.hidden = true;
    mermaidViewer.setAttribute('aria-hidden', 'true');
    mermaidViewerContent.replaceChildren();
    viewerState.dragging = false;
    viewerState.pointerId = null;
  }

  function setupMermaidViewer() {
    mermaidZoomOutBtn.addEventListener('click', () => setViewerScale(viewerState.scale / 1.25));
    mermaidZoomInBtn.addEventListener('click', () => setViewerScale(viewerState.scale * 1.25));
    mermaidZoomResetBtn.addEventListener('click', () => centerViewerAtScale(1));
    mermaidFitBtn.addEventListener('click', fitMermaidViewer);
    mermaidCloseBtn.addEventListener('click', closeMermaidViewer);

    mermaidViewer.addEventListener('click', (event) => {
      if (event.target === mermaidViewer) closeMermaidViewer();
    });

    mermaidViewerCanvas.addEventListener('wheel', (event) => {
      event.preventDefault();
      const direction = event.deltaY < 0 ? 1.12 : 1 / 1.12;
      setViewerScale(viewerState.scale * direction);
    }, { passive: false });

    mermaidViewerCanvas.addEventListener('pointerdown', (event) => {
      if (event.button !== 0) return;
      viewerState.dragging = true;
      viewerState.pointerId = event.pointerId;
      viewerState.startPointerX = event.clientX;
      viewerState.startPointerY = event.clientY;
      viewerState.startX = viewerState.x;
      viewerState.startY = viewerState.y;
      mermaidViewerCanvas.classList.add('is-dragging');
      mermaidViewerCanvas.setPointerCapture(event.pointerId);
    });

    mermaidViewerCanvas.addEventListener('pointermove', (event) => {
      if (!viewerState.dragging || event.pointerId !== viewerState.pointerId) return;
      viewerState.x = viewerState.startX + event.clientX - viewerState.startPointerX;
      viewerState.y = viewerState.startY + event.clientY - viewerState.startPointerY;
      applyViewerTransform();
    });

    const stopDragging = (event) => {
      if (!viewerState.dragging) return;
      if (event.pointerId !== undefined && event.pointerId !== viewerState.pointerId) return;
      viewerState.dragging = false;
      mermaidViewerCanvas.classList.remove('is-dragging');
      viewerState.pointerId = null;
    };

    mermaidViewerCanvas.addEventListener('pointerup', stopDragging);
    mermaidViewerCanvas.addEventListener('pointercancel', stopDragging);

    window.addEventListener('resize', () => {
      if (!mermaidViewer.hidden) fitMermaidViewer();
    });
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

  function loadDocument(documentData) {
    if (!documentData) return;
    state.path = documentData.path || null;
    state.name = documentData.name || 'documento.md';
    state.savedContent = documentData.content || '';
    editor.value = state.savedContent;
    editor.scrollTop = 0;
    preview.scrollTop = 0;
    addRecent(documentData);
    resetHistory();
    refreshPreview();
  }

  function syncSavedDocument(documentData) {
    if (!documentData) return;
    state.path = documentData.path || state.path;
    state.name = documentData.name || state.name;
    state.savedContent = documentData.content ?? editor.value;
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
    resetHistory();
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
      syncSavedDocument(result);
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
      syncSavedDocument(result);
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
    if (state.mode === 'preview') setMode('split');
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

    commitHistory('guide');
    schedulePreview();
  }

  async function loadStartupDocument() {
    renderGuide();
    renderRecents();
    setActivePanel(state.activePanel);

    if (!requireTauri()) {
      resetHistory();
      refreshPreview();
      return;
    }

    try {
      const result = await invoke('startup_document');
      if (result) loadDocument(result);
      else {
        resetHistory();
        refreshPreview();
      }
    } catch (error) {
      showToast(String(error), true);
      resetHistory();
      refreshPreview();
    }
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
      openMermaidViewer(block?.dataset.mermaidSvg || '');
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
  loadStartupDocument();
})();

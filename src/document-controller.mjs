import { normalizeLineEndings, serializeDocument } from './document-format.mjs';

export function createDocumentController({ editor, preview, state, invoke, requireTauri, showToast, addRecent, removeRecent, resetHistory, refreshPreview, confirmDiscard = () => window.confirm('Ci sono modifiche non salvate. Vuoi scartarle?') }) {
  function isDirty() {
    return editor.value !== state.savedContent;
  }

  function loadDocument(documentData) {
    if (!documentData) return;
    state.path = documentData.path || null;
    state.name = documentData.name || 'documento.md';
    state.savedFileContent = documentData.content ?? '';
    state.savedContent = normalizeLineEndings(state.savedFileContent);
    editor.value = state.savedContent;
    editor.scrollTop = 0;
    preview.scrollTop = 0;
    addRecent(documentData);
    resetHistory();
    refreshPreview();
  }

  function syncSavedDocument(documentData, snapshot, fileContent) {
    if (!documentData) return;
    state.path = documentData.path || state.path;
    state.name = documentData.name || state.name;
    state.savedContent = snapshot;
    state.savedFileContent = fileContent;
    addRecent(documentData);
    refreshPreview();
  }

  function confirmDiscardIfNeeded() {
    if (!isDirty()) return true;
    return confirmDiscard();
  }

  function newDocument() {
    if (state.documentBusy || !confirmDiscardIfNeeded()) return;
    state.path = null;
    state.name = 'Senza titolo.md';
    state.savedContent = '';
    state.savedFileContent = '';
    editor.value = '';
    resetHistory();
    refreshPreview();
    editor.focus();
  }

  async function withDocumentOperation(operation) {
    if (state.documentBusy) {
      showToast('Attendi la conclusione dell’operazione sul documento.');
      return false;
    }
    state.documentBusy = true;
    try {
      return await operation();
    } finally {
      state.documentBusy = false;
    }
  }

  async function openDocument() {
    if (!requireTauri()) return;
    return withDocumentOperation(async () => {
      try {
        const result = await invoke('open_document');
        if (result && confirmDiscardIfNeeded()) loadDocument(result);
      } catch (error) {
        showToast(String(error), true);
      }
    });
  }

  async function openRecent(path) {
    if (!requireTauri()) return;
    return withDocumentOperation(async () => {
      try {
        const result = await invoke('open_document_path', { path });
        if (confirmDiscardIfNeeded()) loadDocument(result);
      } catch (error) {
        showToast('Impossibile aprire il file recente: ' + String(error), true);
      }
    });
  }

  async function saveAs() {
    if (!requireTauri()) return false;
    return withDocumentOperation(async () => {
      const snapshot = editor.value;
      const fileContent = serializeDocument(snapshot, state.savedFileContent);
      try {
        const suggestedName = state.path ? state.name : 'documento.md';
        const result = await invoke('save_document_as', {
          content: fileContent,
          suggestedName,
        });
        if (!result) return false;
        syncSavedDocument(result, snapshot, fileContent);
        showToast(isDirty() ? 'Versione precedente salvata; restano modifiche.' : 'File salvato.');
        return true;
      } catch (error) {
        showToast(String(error), true);
        return false;
      }
    });
  }

  async function saveDocument() {
    if (!requireTauri()) return false;
    if (!state.path) return saveAs();
    return withDocumentOperation(async () => {
      const snapshot = editor.value;
      const fileContent = serializeDocument(snapshot, state.savedFileContent);
      try {
        const result = await invoke('save_document', {
          path: state.path,
          content: fileContent,
        });
        syncSavedDocument(result, snapshot, fileContent);
        showToast(isDirty() ? 'Versione precedente salvata; restano modifiche.' : 'Salvato.');
        return true;
      } catch (error) {
        showToast(String(error), true);
        return false;
      }
    });
  }

  async function loadStartupDocument() {
    if (!requireTauri()) {
      resetHistory();
      refreshPreview();
      return;
    }

    resetHistory();
    await withDocumentOperation(async () => {
      try {
        const result = await invoke('startup_document');
        if (result && confirmDiscardIfNeeded()) loadDocument(result);
        else refreshPreview();
      } catch (error) {
        showToast(String(error), true);
        refreshPreview();
      }
    });
  }

  return { isDirty, confirmDiscardIfNeeded, newDocument, openDocument, openRecent, saveDocument, saveAs, loadStartupDocument };
}

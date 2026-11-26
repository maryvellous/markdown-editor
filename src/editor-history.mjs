export function createEditorHistory({ editor, undoBtn, redoBtn, schedulePreview }) {
  const state = { history: [], historyIndex: -1, historyLastKind: null, historyLastAt: 0, applyingHistory: false };

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

  return { resetHistory, commitHistory, undoEditor, redoEditor };
}

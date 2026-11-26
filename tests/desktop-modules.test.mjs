import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createEditorHistory } from '../src/editor-history.mjs';
import { createDocumentController } from '../src/document-controller.mjs';
import { createRecentDocuments } from '../src/recent-documents.mjs';

function editorStub() {
  return { value: '', selectionStart: 0, selectionEnd: 0,
    setSelectionRange(start, end) { this.selectionStart = start; this.selectionEnd = end; },
    focus() {}, scrollTop: 0 };
}

test('history restores selection and discards redo branch after a new edit', () => {
  const editor = editorStub(), undoBtn = {}, redoBtn = {};
  const h = createEditorHistory({ editor, undoBtn, redoBtn, schedulePreview() {} });
  h.resetHistory();
  assert.equal(undoBtn.disabled, true);
  editor.value = 'one'; editor.setSelectionRange(1, 2); h.commitHistory('guide');
  editor.value = 'two'; editor.setSelectionRange(3, 3); h.commitHistory('guide');
  h.undoEditor();
  assert.deepEqual([editor.value, editor.selectionStart, editor.selectionEnd], ['one', 1, 2]);
  assert.equal(redoBtn.disabled, false);
  h.redoEditor();
  assert.equal(editor.value, 'two');
  h.undoEditor();
  editor.value = 'branch'; h.commitHistory('guide');
  assert.equal(redoBtn.disabled, true);
  h.redoEditor();
  assert.equal(editor.value, 'branch');
});

function fixture(invoke, confirmDiscard = () => true) {
  const editor = editorStub(), preview = { scrollTop: 0 };
  const state = { path: null, name: 'Senza titolo.md', savedContent: '',
    savedFileContent: '', documentBusy: false };
  const controller = createDocumentController({ editor, preview, state, invoke,
    requireTauri: () => true, showToast() {}, addRecent() {}, removeRecent() {},
    resetHistory() {}, refreshPreview() {}, confirmDiscard });
  return { editor, state, controller };
}

test('opening CRLF is clean and saving keeps its original separator', async () => {
  const original = { path: 'a.md', name: 'a.md', content: 'a\r\nb\r\n' };
  let saved;
  const f = fixture(async (command, args) => {
    if (command === 'open_document') return original;
    if (command === 'save_document') {
      saved = args.content;
      return { ...original, content: saved };
    }
    throw Error(command);
  });
  await f.controller.openDocument();
  assert.equal(f.controller.isDirty(), false);
  f.editor.value = 'a\nchanged\n';
  assert.equal(f.controller.isDirty(), true);
  assert.equal(await f.controller.saveDocument(), true);
  assert.equal(saved, 'a\r\nchanged\r\n');
  assert.equal(f.controller.isDirty(), false);
});

test('pending save blocks another operation and preserves later edits', async () => {
  let finishSave, calls = 0;
  const f = fixture((command) => {
    calls++;
    assert.equal(command, 'save_document_as');
    return new Promise((resolve) => { finishSave = resolve; });
  });
  f.editor.value = 'snapshot';
  const pending = f.controller.saveAs();
  f.editor.value = 'new edit';
  assert.equal(await f.controller.openDocument(), false);
  assert.equal(calls, 1);
  finishSave({ path: 'saved.md', name: 'saved.md', content: 'snapshot' });
  assert.equal(await pending, true);
  assert.equal(f.editor.value, 'new edit');
  assert.equal(f.state.savedContent, 'snapshot');
  assert.equal(f.controller.isDirty(), true);
  assert.equal(f.state.documentBusy, false);
});

test('cancelled save or rejected discard keeps the original document', async () => {
  const f = fixture(async (command) => {
    if (command === 'save_document_as') return null;
    return { path: 'other.md', name: 'other.md', content: 'other' };
  }, () => false);
  f.editor.value = 'unsaved';
  assert.equal(await f.controller.saveAs(), false);
  await f.controller.openDocument();
  f.controller.newDocument();
  assert.equal(f.editor.value, 'unsaved');
  assert.equal(f.state.path, null);
  assert.equal(f.controller.isDirty(), true);
  assert.equal(f.state.documentBusy, false);
});

test('recent documents handle denied storage and malformed JSON', () => {
  const recentList = { replaceChildren() {} }, recentEmpty = {}, clearRecentBtn = {};
  const broken = createRecentDocuments({ recentList, recentEmpty, clearRecentBtn,
    openRecent() {}, getStorage() { throw Error('denied'); } });
  broken.renderRecents();
  broken.storeRecents([]);
  assert.equal(recentEmpty.hidden, false);
  assert.equal(clearRecentBtn.disabled, true);
  const malformed = createRecentDocuments({ recentList, recentEmpty, clearRecentBtn,
    openRecent() {}, getStorage: () => ({ getItem: () => 'not json' }) });
  malformed.renderRecents();
  assert.equal(clearRecentBtn.disabled, true);
});


test('desktop entrypoint initializes guide, recents, history and preview together', async () => {
  const elements = new Map();
  function element() {
    return {
      value: '', selectionStart: 0, selectionEnd: 0, dataset: {}, children: [],
      classList: { add() {}, remove() {}, toggle() {} },
      listeners: new Map(),
      addEventListener(name, fn) { this.listeners.set(name, fn); },
      append(...children) { this.children.push(...children); },
      appendChild(child) { this.children.push(child); },
      replaceChildren() { this.children = []; },
      setAttribute() {}, focus() {},
    };
  }
  function getElementById(id) {
    if (!elements.has(id)) elements.set(id, element());
    return elements.get(id);
  }
  const calls = [];
  const previousWindow = globalThis.window, previousDocument = globalThis.document;
  globalThis.document = { getElementById, createElement: element,
    querySelectorAll: () => [], addEventListener() {} };
  globalThis.window = {
    __TAURI__: { core: { invoke: async (command) => { calls.push(command); return null; } } },
    localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    clearTimeout() {}, setTimeout() {}, addEventListener() {},
  };
  try {
    await import('../src/app.js');
    await new Promise((resolve) => setImmediate(resolve));
    assert.deepEqual(calls, ['startup_document']);
    assert.equal(getElementById('saveState').textContent, 'Salvato');
    assert.equal(getElementById('undoBtn').disabled, true);
    assert.equal(getElementById('redoBtn').disabled, true);
    assert.equal(getElementById('recentEmpty').hidden, false);
    assert.equal(getElementById('markdownGuide').children.length, 19);
    assert.match(getElementById('preview').innerHTML, /anteprima comparirà/);
    for (const id of ['newBtn', 'openBtn', 'saveBtn', 'saveAsBtn', 'mermaidFitBtn']) {
      assert.equal(typeof getElementById(id).listeners.get('click'), 'function', id);
    }
  } finally {
    if (previousWindow === undefined) delete globalThis.window;
    else globalThis.window = previousWindow;
    if (previousDocument === undefined) delete globalThis.document;
    else globalThis.document = previousDocument;
  }
});

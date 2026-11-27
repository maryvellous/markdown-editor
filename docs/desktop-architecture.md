# Desktop architecture

The desktop uses native ES modules (no bundler or framework). `src/app.js` composes controllers, connects DOM events, owns the preview scheduler and shared document/UI metadata.

- `document-controller.mjs`: document commands, operation serialization, dirty confirmation, save snapshots and startup.
- `document-format.mjs`: line ending normalization and serialization.
- `editor-history.mjs`: editor snapshots, history coalescing, undo/redo and button state.
- `recent-documents.mjs`: validated local storage and rendering of recent files.
- `markdown-guide.mjs`: guide definitions and editor insertion.
- `mermaid-renderer.mjs`: strict Mermaid initialization, diagram cache and version-aware rendering.
- `mermaid-viewer.mjs`: full-screen diagram state, zoom, pan and events.

Controllers receive DOM elements, services and callbacks from the entrypoint. The document controller retains shared document state for the UI; history and Mermaid state stay in their own closures. Rust commands, markup, CSS, storage keys and intended UX remain unchanged.

Regression checks: `node --test tests/document-format.test.mjs tests/desktop-modules.test.mjs` and the Rust tests. Tests use isolated stubs for document commands, history and storage. Real WebView and installer behavior still require local validation.

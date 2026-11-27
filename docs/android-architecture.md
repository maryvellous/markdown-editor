# Android architecture

The Flutter app uses native Dart files and Flutter state, without additional dependencies or state-management frameworks.

- `main.dart`: entrypoint, theme and composition of private UI parts.
- `editor_home.dart`: lifecycle, document operations, recent-file persistence and screen orchestration; the existing SAF MethodChannel contract is unchanged.
- `editor_models.dart`: editor mode and recent-document model.
- `markdown_guide.dart`: guide definitions and pure editing/selection logic.
- `preview_segments.dart`: pure Markdown/Mermaid segmentation.
- `editor_workspace.dart`, `markdown_preview.dart`, `editor_chrome.dart`: private UI parts for panes, preview and full-screen viewer, toolbar, status and sheet components.

Private UI parts deliberately share the app library to preserve existing widget visibility and palette. Independent guide and parser modules have direct unit tests. Existing document and Mermaid widget tests remain in place. No UI, dependencies, native channel, preference format or release version changes are intended. CI runs analysis, all Flutter tests and APK build; real-device validation is separate.

part of 'main.dart';

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.mode,
    required this.editor,
    required this.editorFocus,
    required this.undoController,
  });

  final EditorMode mode;
  final TextEditingController editor;
  final FocusNode editorFocus;
  final UndoHistoryController undoController;

  @override
  Widget build(BuildContext context) {
    final editorPane = _EditorPane(
      controller: editor,
      focusNode: editorFocus,
      undoController: undoController,
    );
    final previewPane = _PreviewPane(markdown: editor.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: switch (mode) {
        EditorMode.edit => editorPane,
        EditorMode.preview => previewPane,
        EditorMode.split => Row(
            children: <Widget>[
              Expanded(child: editorPane),
              const SizedBox(width: 10),
              Expanded(child: previewPane),
            ],
          ),
      },
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({
    required this.controller,
    required this.focusNode,
    required this.undoController,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final UndoHistoryController undoController;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      label: 'MARKDOWN',
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              undoController: undoController,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                color: Color(0xFFF7F2E8),
                fontFamily: 'monospace',
                fontSize: 15,
                height: 1.58,
              ),
              cursorColor: _sand,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(18, 52, 18, 72),
                hintText: '# Inizia a scrivere…',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 7,
            child: _UndoRedoButtons(controller: undoController),
          ),
        ],
      ),
    );
  }
}

class _UndoRedoButtons extends StatelessWidget {
  const _UndoRedoButtons({required this.controller});

  final UndoHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _canvas.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _lavender.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Annulla',
                iconSize: 19,
                visualDensity: VisualDensity.compact,
                onPressed: value.canUndo ? controller.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Ripristina',
                iconSize: 19,
                visualDensity: VisualDensity.compact,
                onPressed: value.canRedo ? controller.redo : null,
                icon: const Icon(Icons.redo),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      label: 'ANTEPRIMA',
      light: true,
      child: markdown.trim().isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _BrandMark(compact: false),
                  SizedBox(height: 14),
                  Text(
                    'L’anteprima comparirà qui mentre scrivi.',
                    style: TextStyle(color: Color(0xFF5E5069)),
                  ),
                ],
              ),
            )
          : Theme(
              data: ThemeData.light(useMaterial3: true).copyWith(
                textTheme: ThemeData.light().textTheme.apply(
                      bodyColor: const Color(0xFF291D39),
                      displayColor: _plum,
                    ),
              ),
              child: _MarkdownPreview(markdown: markdown),
            ),
    );
  }
}

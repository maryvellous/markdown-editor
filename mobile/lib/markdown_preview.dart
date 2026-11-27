part of 'main.dart';

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final parts = splitMarkdownPreview(markdown);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 70),
      children: <Widget>[
        for (final part in parts)
          if (part.isMermaid)
            _MermaidPreviewCard(source: part.content)
          else if (part.content.trim().isNotEmpty)
            MarkdownBody(
              data: part.content,
              selectable: true,
            ),
      ],
    );
  }
}

class _MermaidPreviewCard extends StatelessWidget {
  const _MermaidPreviewCard({required this.source});

  final String source;

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MermaidFullscreenPage(source: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mermaidTheme = MaterialMermaidTheme.fromTheme(Theme.of(context));
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Container(
        height: 300,
        margin: const EdgeInsets.symmetric(vertical: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _sand.withValues(alpha: 0.7)),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: AbsorbPointer(
                child: MermaidView(
                  source: source,
                  theme: mermaidTheme,
                  backgroundColor: Colors.white,
                  showControls: false,
                  allowFullscreen: false,
                  semanticNodes: true,
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Diagramma Mermaid non valido:\n$error',
                      style: const TextStyle(
                        color: Color(0xFF6E3945),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _canvas.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.open_in_full, size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Tocca per ingrandire',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MermaidFullscreenPage extends StatefulWidget {
  const _MermaidFullscreenPage({required this.source});

  final String source;

  @override
  State<_MermaidFullscreenPage> createState() => _MermaidFullscreenPageState();
}

class _MermaidFullscreenPageState extends State<_MermaidFullscreenPage> {
  final TransformationController _transform = TransformationController();
  int _viewportRevision = 0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _resetView() {
    // Recreate the gesture surface to cancel any pending pan/scale inertia.
    _transform.value = Matrix4.identity();
    setState(() => _viewportRevision++);
  }

  void _toggleZoom() {
    final currentScale = _transform.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _resetView();
      return;
    }
    _transform.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final mermaidTheme = MaterialMermaidTheme.fromTheme(
      ThemeData.light(useMaterial3: true),
    );

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text(
          'Diagramma Mermaid',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Adatta alla schermata',
            onPressed: _resetView,
            icon: const Icon(Icons.fit_screen),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                key: ValueKey(_viewportRevision),
                transformationController: _transform,
                minScale: 1,
                maxScale: 8,
                panEnabled: true,
                scaleEnabled: true,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    // MermaidView fits the diagram itself; only the outer viewer
                    // may handle pan/zoom gestures. Hidden controls alone do not
                    // disable MermaidView's internal gestures.
                    child: AbsorbPointer(
                      child: MermaidView(
                        source: widget.source,
                        theme: mermaidTheme,
                        backgroundColor: Colors.white,
                        showControls: false,
                        allowFullscreen: false,
                        semanticNodes: true,
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Diagramma Mermaid non valido:\n$error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF6E3945),
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

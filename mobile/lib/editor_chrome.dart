part of 'main.dart';

class _Pane extends StatelessWidget {
  const _Pane({required this.label, required this.child, this.light = false});

  final String label;
  final Widget child;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: light ? _paper : _card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: light
              ? _sand.withValues(alpha: 0.36)
              : _lavender.withValues(alpha: 0.22),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: child),
          Positioned(
            top: 12,
            right: 14,
            child: Text(
              label,
              style: TextStyle(
                color: light
                    ? _canvas.withValues(alpha: 0.56)
                    : _blue.withValues(alpha: 0.76),
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideToolbar extends StatelessWidget {
  const _WideToolbar({
    required this.mode,
    required this.onModeChanged,
    required this.onNew,
    required this.onOpen,
    required this.onSaveAs,
    required this.onSave,
    required this.onRecent,
    required this.onGuide,
  });

  final EditorMode mode;
  final ValueChanged<EditorMode> onModeChanged;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSaveAs;
  final VoidCallback onSave;
  final VoidCallback onRecent;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _canvas,
        border: Border(
          bottom: BorderSide(color: _lavender.withValues(alpha: 0.16)),
        ),
      ),
      width: double.infinity,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SegmentedButton<EditorMode>(
            segments: const <ButtonSegment<EditorMode>>[
              ButtonSegment(
                value: EditorMode.edit,
                icon: Icon(Icons.edit_note_outlined),
                label: Text('Scrivi'),
              ),
              ButtonSegment(
                value: EditorMode.split,
                icon: Icon(Icons.vertical_split_outlined),
                label: Text('Affianca'),
              ),
              ButtonSegment(
                value: EditorMode.preview,
                icon: Icon(Icons.visibility_outlined),
                label: Text('Leggi'),
              ),
            ],
            selected: <EditorMode>{mode},
            onSelectionChanged: (value) => onModeChanged(value.first),
          ),
          IconButton(
            tooltip: 'Recenti',
            onPressed: onRecent,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Guida Markdown',
            onPressed: onGuide,
            icon: const Icon(Icons.menu_book_outlined),
          ),
          TextButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Nuovo'),
          ),
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Apri'),
          ),
          TextButton.icon(
            onPressed: onSaveAs,
            icon: const Icon(Icons.save_as_outlined),
            label: const Text('Salva con nome'),
          ),
          FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.dirty,
    required this.wordCount,
    required this.charCount,
  });

  final bool dirty;
  final int wordCount;
  final int charCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: _lavender.withValues(alpha: 0.16)),
        ),
      ),
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: (dirty ? _sand : _sage).withValues(alpha: 0.08),
              border: Border.all(
                color: (dirty ? _sand : _sage).withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              dirty ? 'Modifiche non salvate' : 'Salvato',
              style: TextStyle(
                color: dirty ? _sand : _sage,
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ),
          Text(
            '$wordCount ${wordCount == 1 ? 'parola' : 'parole'} · '
            '$charCount ${charCount == 1 ? 'carattere' : 'caratteri'}',
            style: const TextStyle(
              color: Colors.white60,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 46.0 : 70.0;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/app_icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: _blue,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          IconButton(
            tooltip: 'Chiudi',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

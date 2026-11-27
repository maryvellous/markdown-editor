part of 'main.dart';

class EditorHome extends StatefulWidget {
  const EditorHome({super.key});

  @override
  State<EditorHome> createState() => _EditorHomeState();
}

class _EditorHomeState extends State<EditorHome> with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.diaspro.markdown/files');
  static const _recentsKey = 'recents.v1';

  final _editor = TextEditingController();
  final _editorFocus = FocusNode();
  UndoHistoryController _undoController = UndoHistoryController();
  final List<RecentDocument> _recents = <RecentDocument>[];

  String _name = 'Senza titolo.md';
  String? _uri;
  String _savedContent = '';
  EditorMode _mode = EditorMode.edit;
  bool _loading = true;
  bool _documentBusy = false;
  bool _pendingCheckRequested = false;

  bool get _dirty => _editor.text != _savedContent;

  int get _wordCount {
    final text = _editor.text.trim();
    return text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editor.addListener(_onEditorChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _editor.removeListener(_onEditorChanged);
    _editor.dispose();
    _editorFocus.dispose();
    _undoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _takePendingDocument();
    }
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await _loadRecents();
    await _takePendingDocument();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRecents() async {
    try {
      final raw = await _channel.invokeMethod<String>(
        'getPreference',
        <String, dynamic>{'key': _recentsKey},
      );
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _recents
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map(
                (item) => RecentDocument.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .take(8),
        );
    } on PlatformException {
      // La cronologia non è essenziale al funzionamento dell'editor.
    } on FormatException {
      _recents.clear();
    } on TypeError {
      _recents.clear();
    }
  }

  Future<void> _persistRecents() async {
    try {
      await _channel.invokeMethod<void>(
        'setPreference',
        <String, dynamic>{
          'key': _recentsKey,
          'value': jsonEncode(_recents.map((item) => item.toJson()).toList()),
        },
      );
    } on PlatformException {
      // Ignora errori di persistenza: il documento resta utilizzabile.
    }
  }

  Future<void> _runDocumentOperation(Future<void> Function() operation) async {
    if (!mounted || _documentBusy) return;
    setState(() => _documentBusy = true);
    try {
      await operation();
    } finally {
      if (mounted) {
        setState(() => _documentBusy = false);
        if (_pendingCheckRequested) {
          _pendingCheckRequested = false;
          await _takePendingDocument();
        }
      }
    }
  }

  Future<void> _takePendingDocument() async {
    if (_documentBusy) {
      _pendingCheckRequested = true;
      return;
    }
    await _runDocumentOperation(() async {
      try {
        final data = await _channel.invokeMapMethod<String, dynamic>(
          'takePendingDocument',
        );
        if (data != null && mounted && await _confirmDiscard() && mounted) {
          _loadDocument(data, addToRecents: true);
        }
      } on PlatformException catch (error) {
        _showError(error.message ?? 'Impossibile aprire il documento ricevuto.');
      }
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifiche non salvate'),
        content: const Text('Vuoi scartare le modifiche a questo documento?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Scarta'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _newDocument() => _runDocumentOperation(() async {
    if (!await _confirmDiscard() || !mounted) return;
    _resetUndoHistory();
    setState(() {
      _name = 'Senza titolo.md';
      _uri = null;
      _savedContent = '';
      _editor.text = '';
      _mode = EditorMode.edit;
    });
    _editorFocus.requestFocus();
  });

  Future<void> _openDocument() => _runDocumentOperation(() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'pickOpenDocument',
      );
      if (data != null && mounted && await _confirmDiscard() && mounted) {
        _loadDocument(data, addToRecents: true);
      }
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Impossibile aprire il file.');
    }
  });

  Future<void> _save() async {
    if (_uri == null || _uri!.isEmpty) {
      await _saveAs();
      return;
    }
    await _runDocumentOperation(() async {
      final snapshot = _editor.text;
      try {
        final data = await _channel.invokeMapMethod<String, dynamic>(
          'writeDocument',
          <String, dynamic>{'uri': _uri, 'content': snapshot},
        );
        if (data != null && mounted) _completeSave(data, snapshot);
      } on PlatformException catch (error) {
        _showError(error.message ?? 'Impossibile salvare il file.');
      }
    });
  }

  Future<void> _saveAs() => _runDocumentOperation(() async {
    final snapshot = _editor.text;
    final suggestedName = _name.toLowerCase().endsWith('.md')
        ? _name
        : '${_name.trim().isEmpty ? 'documento' : _name}.md';
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'createDocument',
        <String, dynamic>{
          'suggestedName': suggestedName,
          'content': snapshot,
        },
      );
      if (data != null && mounted) _completeSave(data, snapshot);
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Impossibile creare il file.');
    }
  });

  void _completeSave(Map<String, dynamic> data, String snapshot) {
    final uri = data['uri'] as String?;
    setState(() {
      _name = data['name'] as String? ?? _name;
      _uri = uri == null || uri.isEmpty ? _uri : uri;
      _savedContent = snapshot;
    });
    _rememberCurrentDocument();
    _showMessage(_dirty ? 'Versione precedente salvata; restano modifiche.' : 'Salvato.');
  }

  void _loadDocument(
    Map<String, dynamic> data, {
    required bool addToRecents,
  }) {
    final content = data['content'] as String? ?? '';
    final uri = data['uri'] as String?;
    final name = data['name'] as String? ?? 'documento.md';

    _resetUndoHistory();
    setState(() {
      _name = name;
      _uri = uri == null || uri.isEmpty ? null : uri;
      _savedContent = content;
      _editor.value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
      );
    });

    if (addToRecents) _rememberCurrentDocument();
  }

  void _resetUndoHistory() {
    final previous = _undoController;
    _undoController = UndoHistoryController();
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void _rememberCurrentDocument() {
    final current = RecentDocument(
      name: _name,
      uri: _uri,
      content: _savedContent,
      openedAt: DateTime.now().toIso8601String(),
    );
    final identity = _uri ?? _name;
    _recents.removeWhere((item) => (item.uri ?? item.name) == identity);
    _recents.insert(0, current);
    if (_recents.length > 8) _recents.removeRange(8, _recents.length);
    _persistRecents();
  }

  Future<void> _openRecent(RecentDocument recent) async {
    Navigator.pop(context);
    await _runDocumentOperation(() async {
      Map<String, dynamic>? data;
      if (recent.uri != null && recent.uri!.isNotEmpty) {
        try {
          data = await _channel.invokeMapMethod<String, dynamic>(
            'readDocument',
            <String, dynamic>{'uri': recent.uri},
          );
        } on PlatformException {
          // Se il provider non concede più accesso, apri la copia locale recente.
        }
      }
      if (!mounted || !await _confirmDiscard() || !mounted) return;
      if (data != null) {
        _loadDocument(data, addToRecents: true);
        return;
      }
      _loadDocument(
        <String, dynamic>{
          'name': recent.name,
          'content': recent.content,
          'uri': '',
        },
        addToRecents: true,
      );
      _showMessage('Aperta la copia recente. Usa “Salva con nome” per conservarla.');
    });
  }

  void _insertGuideItem(GuideItem item) {
    Navigator.pop(context);
    _editor.value = applyGuideItem(_editor.value, item);
    setState(() => _mode = EditorMode.edit);
    _editorFocus.requestFocus();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF6E3945),
        ),
      );
  }

  void _showRecents() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.68,
          child: Column(
            children: <Widget>[
              _SheetHeader(
                eyebrow: 'CRONOLOGIA',
                title: 'Recenti',
                trailing: _recents.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () {
                          setState(() => _recents.clear());
                          _persistRecents();
                          Navigator.pop(context);
                        },
                        child: const Text('Svuota'),
                      ),
              ),
              Expanded(
                child: _recents.isEmpty
                    ? const Center(
                        child: Text(
                          'I file aperti di recente compariranno qui.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: _recents.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _recents[index];
                          return ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.uri == null
                                  ? 'Copia locale recente'
                                  : 'Documento Android',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openRecent(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.74,
          child: Column(
            children: <Widget>[
              const _SheetHeader(
                eyebrow: 'MARKDOWN',
                title: 'Guida rapida',
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tocca una sintassi per inserirla nel punto del cursore.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: markdownGuide.length,
                  itemBuilder: (context, index) {
                    final item = markdownGuide[index];
                    return ListTile(
                      title: Text(item.label),
                      trailing: Container(
                        constraints: const BoxConstraints(maxWidth: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _canvas,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.syntax,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _sand,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () => _insertGuideItem(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenu(String action) {
    switch (action) {
      case 'new':
        _newDocument();
        break;
      case 'saveAs':
        _saveAs();
        break;
      case 'recents':
        _showRecents();
        break;
      case 'guide':
        _showGuide();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_documentBusy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _documentBusy) return;
        await _runDocumentOperation(() async {
          if (await _confirmDiscard() && context.mounted) {
            SystemNavigator.pop();
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          titleSpacing: 14,
          title: Row(
            children: <Widget>[
              const _BrandMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (_dirty)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 7),
                            decoration: const BoxDecoration(
                              color: _sand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            _name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _uri == null ? 'Nuovo documento' : 'Documento Android',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Apri',
              onPressed: _openDocument,
              icon: const Icon(Icons.folder_open_outlined),
            ),
            IconButton(
              tooltip: 'Salva',
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'Altre azioni',
              onSelected: _handleMenu,
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem(
                  value: 'new',
                  child: ListTile(
                    leading: Icon(Icons.note_add_outlined),
                    title: Text('Nuovo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'saveAs',
                  child: ListTile(
                    leading: Icon(Icons.save_as_outlined),
                    title: Text('Salva con nome'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'recents',
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Recenti'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'guide',
                  child: ListTile(
                    leading: Icon(Icons.menu_book_outlined),
                    title: Text('Guida Markdown'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final canSplit = constraints.maxWidth >= 700;
            final mode = _mode == EditorMode.split && !canSplit
                ? EditorMode.edit
                : _mode;

            return Column(
              children: <Widget>[
                if (canSplit) _WideToolbar(
                  mode: mode,
                  onModeChanged: (value) => setState(() => _mode = value),
                  onNew: _newDocument,
                  onOpen: _openDocument,
                  onSaveAs: _saveAs,
                  onSave: _save,
                  onRecent: _showRecents,
                  onGuide: _showGuide,
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _Workspace(
                          mode: mode,
                          editor: _editor,
                          editorFocus: _editorFocus,
                          undoController: _undoController,
                        ),
                ),
                _StatusBar(
                  dirty: _dirty,
                  wordCount: _wordCount,
                  charCount: _editor.text.length,
                ),
                if (!canSplit)
                  NavigationBar(
                    height: 68,
                    backgroundColor: _card,
                    indicatorColor: _plum,
                    selectedIndex: mode == EditorMode.preview ? 1 : 0,
                    onDestinationSelected: (index) {
                      setState(() {
                        _mode = index == 0
                            ? EditorMode.edit
                            : EditorMode.preview;
                      });
                    },
                    destinations: const <NavigationDestination>[
                      NavigationDestination(
                        icon: Icon(Icons.edit_note_outlined),
                        selectedIcon: Icon(Icons.edit_note),
                        label: 'Scrivi',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.visibility_outlined),
                        selectedIcon: Icon(Icons.visibility),
                        label: 'Leggi',
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final width = MediaQuery.sizeOf(context).width;
            if (width >= 700 || _mode != EditorMode.edit) {
              return const SizedBox.shrink();
            }
            return FloatingActionButton.small(
              tooltip: 'Guida Markdown',
              backgroundColor: _plum,
              foregroundColor: Colors.white,
              onPressed: _showGuide,
              child: const Icon(Icons.menu_book_outlined),
            );
          },
        ),
      ),
    );
  }
}

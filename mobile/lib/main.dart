import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

const _canvas = Color(0xFF1E1333);
const _card = Color(0xFF2B1C47);
const _lavender = Color(0xFF9D85C6);
const _plum = Color(0xFF7A3F67);
const _sand = Color(0xFFE8D19E);
const _blue = Color(0xFFA5C4DC);
const _sage = Color(0xFF98A78A);
const _paper = Color(0xFFF4ECD9);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiasproMarkdownApp());
}

class DiasproMarkdownApp extends StatelessWidget {
  const DiasproMarkdownApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _plum,
      brightness: Brightness.dark,
      surface: _card,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Diaspro Markdown',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: _canvas,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _card,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        dividerColor: _lavender.withValues(alpha: 0.18),
      ),
      home: const EditorHome(),
    );
  }
}

enum EditorMode { edit, preview, split }

enum GuideKind { wrap, prefix, snippet }

class GuideItem {
  const GuideItem({
    required this.label,
    required this.syntax,
    required this.kind,
    this.before = '',
    this.after = '',
    this.value = '',
    this.placeholder = 'testo',
    this.selectText,
  });

  final String label;
  final String syntax;
  final GuideKind kind;
  final String before;
  final String after;
  final String value;
  final String placeholder;
  final String? selectText;
}

class RecentDocument {
  const RecentDocument({
    required this.name,
    required this.content,
    required this.openedAt,
    this.uri,
  });

  final String name;
  final String content;
  final String openedAt;
  final String? uri;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'content': content,
        'openedAt': openedAt,
        'uri': uri,
      };

  factory RecentDocument.fromJson(Map<String, dynamic> json) {
    return RecentDocument(
      name: json['name'] as String? ?? 'documento.md',
      content: json['content'] as String? ?? '',
      openedAt: json['openedAt'] as String? ?? '',
      uri: (json['uri'] as String?)?.trim().isEmpty == true
          ? null
          : json['uri'] as String?,
    );
  }
}

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
  final List<RecentDocument> _recents = <RecentDocument>[];

  String _name = 'Senza titolo.md';
  String? _uri;
  String _savedContent = '';
  EditorMode _mode = EditorMode.edit;
  bool _loading = true;

  static const _guide = <GuideItem>[
    GuideItem(
      label: 'Titolo',
      syntax: '# Titolo',
      kind: GuideKind.prefix,
      value: '# ',
      placeholder: 'Titolo',
    ),
    GuideItem(
      label: 'Grassetto',
      syntax: '**testo**',
      kind: GuideKind.wrap,
      before: '**',
      after: '**',
    ),
    GuideItem(
      label: 'Corsivo',
      syntax: '*testo*',
      kind: GuideKind.wrap,
      before: '*',
      after: '*',
    ),
    GuideItem(
      label: 'Barrato',
      syntax: '~~testo~~',
      kind: GuideKind.wrap,
      before: '~~',
      after: '~~',
    ),
    GuideItem(
      label: 'Codice inline',
      syntax: '`codice`',
      kind: GuideKind.wrap,
      before: '`',
      after: '`',
      placeholder: 'codice',
    ),
    GuideItem(
      label: 'Citazione',
      syntax: '> testo',
      kind: GuideKind.prefix,
      value: '> ',
    ),
    GuideItem(
      label: 'Elenco',
      syntax: '- voce',
      kind: GuideKind.prefix,
      value: '- ',
      placeholder: 'voce',
    ),
    GuideItem(
      label: 'Elenco numerato',
      syntax: '1. voce',
      kind: GuideKind.prefix,
      value: '1. ',
      placeholder: 'voce',
    ),
    GuideItem(
      label: 'Checkbox',
      syntax: '- [ ] attività',
      kind: GuideKind.prefix,
      value: '- [ ] ',
      placeholder: 'attività',
    ),
    GuideItem(
      label: 'Link',
      syntax: '[testo](url)',
      kind: GuideKind.snippet,
      value: '[testo](https://)',
      selectText: 'testo',
    ),
    GuideItem(
      label: 'Immagine',
      syntax: '![alt](file.png)',
      kind: GuideKind.snippet,
      value: '![descrizione](immagine.png)',
      selectText: 'descrizione',
    ),
    GuideItem(
      label: 'Blocco codice',
      syntax: '```',
      kind: GuideKind.snippet,
      value: '```\nlinguaggio\ncodice\n```',
      selectText: 'codice',
    ),
    GuideItem(
      label: 'Separatore',
      syntax: '---',
      kind: GuideKind.snippet,
      value: '\n---\n',
    ),
    GuideItem(
      label: 'Tabella',
      syntax: '| A | B |',
      kind: GuideKind.snippet,
      value: '| Colonna A | Colonna B |\n| --- | --- |\n| Valore | Valore |',
    ),
  ];

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

  Future<void> _takePendingDocument() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'takePendingDocument',
      );
      if (data != null && mounted) {
        _loadDocument(data, addToRecents: true);
      }
    } on PlatformException {
      // L'app può essere aperta normalmente senza documento iniziale.
    }
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

  Future<void> _newDocument() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _name = 'Senza titolo.md';
      _uri = null;
      _savedContent = '';
      _editor.text = '';
      _mode = EditorMode.edit;
    });
    _editorFocus.requestFocus();
  }

  Future<void> _openDocument() async {
    if (!await _confirmDiscard()) return;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'pickOpenDocument',
      );
      if (data != null && mounted) {
        _loadDocument(data, addToRecents: true);
      }
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Impossibile aprire il file.');
    }
  }

  Future<void> _save() async {
    if (_uri == null || _uri!.isEmpty) {
      await _saveAs();
      return;
    }

    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'writeDocument',
        <String, dynamic>{'uri': _uri, 'content': _editor.text},
      );
      if (data != null) {
        _loadDocument(data, addToRecents: true);
        _showMessage('Salvato.');
      }
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Impossibile salvare il file.');
    }
  }

  Future<void> _saveAs() async {
    final suggestedName = _name.toLowerCase().endsWith('.md')
        ? _name
        : '${_name.trim().isEmpty ? 'documento' : _name}.md';
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'createDocument',
        <String, dynamic>{
          'suggestedName': suggestedName,
          'content': _editor.text,
        },
      );
      if (data != null) {
        _loadDocument(data, addToRecents: true);
        _showMessage('File salvato.');
      }
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Impossibile creare il file.');
    }
  }

  void _loadDocument(
    Map<String, dynamic> data, {
    required bool addToRecents,
  }) {
    final content = data['content'] as String? ?? '';
    final uri = data['uri'] as String?;
    final name = data['name'] as String? ?? 'documento.md';

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

  void _rememberCurrentDocument() {
    final current = RecentDocument(
      name: _name,
      uri: _uri,
      content: _editor.text,
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
    if (!await _confirmDiscard()) return;

    if (recent.uri != null && recent.uri!.isNotEmpty) {
      try {
        final data = await _channel.invokeMapMethod<String, dynamic>(
          'readDocument',
          <String, dynamic>{'uri': recent.uri},
        );
        if (data != null) {
          _loadDocument(data, addToRecents: true);
          return;
        }
      } on PlatformException {
        // Se il provider non concede più accesso, apri la copia locale recente.
      }
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
  }

  void _insertGuideItem(GuideItem item) {
    Navigator.pop(context);
    final text = _editor.text;
    var selection = _editor.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }

    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);
    late final String insertion;
    int? selectStart;
    int? selectEnd;

    switch (item.kind) {
      case GuideKind.wrap:
        final body = selected.isEmpty ? item.placeholder : selected;
        insertion = '${item.before}$body${item.after}';
        if (selected.isEmpty) {
          selectStart = start + item.before.length;
          selectEnd = selectStart + body.length;
        }
        break;
      case GuideKind.prefix:
        if (selected.isNotEmpty) {
          insertion = selected
              .split('\n')
              .map((line) => '${item.value}$line')
              .join('\n');
        } else {
          insertion = '${item.value}${item.placeholder}';
          selectStart = start + item.value.length;
          selectEnd = selectStart + item.placeholder.length;
        }
        break;
      case GuideKind.snippet:
        insertion = item.value;
        if (item.selectText != null) {
          final offset = insertion.indexOf(item.selectText!);
          if (offset >= 0) {
            selectStart = start + offset;
            selectEnd = selectStart + item.selectText!.length;
          }
        }
        break;
    }

    final next = text.replaceRange(start, end, insertion);
    final nextSelection = selectStart != null && selectEnd != null
        ? TextSelection(baseOffset: selectStart, extentOffset: selectEnd)
        : TextSelection.collapsed(offset: start + insertion.length);
    _editor.value = TextEditingValue(text: next, selection: nextSelection);
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
                  itemCount: _guide.length,
                  itemBuilder: (context, index) {
                    final item = _guide[index];
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
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          SystemNavigator.pop();
        }
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

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.mode,
    required this.editor,
    required this.editorFocus,
  });

  final EditorMode mode;
  final TextEditingController editor;
  final FocusNode editorFocus;

  @override
  Widget build(BuildContext context) {
    final editorPane = _EditorPane(
      controller: editor,
      focusNode: editorFocus,
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
  const _EditorPane({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      label: 'MARKDOWN',
      child: TextField(
        controller: controller,
        focusNode: focusNode,
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
          contentPadding: EdgeInsets.fromLTRB(18, 42, 18, 72),
          hintText: '# Inizia a scrivere…',
          hintStyle: TextStyle(color: Colors.white38),
        ),
      ),
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
              ),            )
          : Theme(
              data: ThemeData.light(useMaterial3: true).copyWith(
                textTheme: ThemeData.light().textTheme.apply(
                      bodyColor: const Color(0xFF291D39),
                      displayColor: _plum,
                    ),
              ),
              child: Markdown(
                data: markdown,
                selectable: true,
                padding: const EdgeInsets.fromLTRB(20, 42, 20, 70),
              ),
            ),
    );
  }
}

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
      child: Row(
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
          const Spacer(),
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
          const SizedBox(width: 6),
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
          const SizedBox(width: 6),
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
      minHeight: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: _lavender.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
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
          const Spacer(),
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
    final size = compact ? 38.0 : 58.0;
    return SizedBox(
      width: size + 8,
      height: size + 5,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            top: 2,
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _plum,
                  borderRadius: BorderRadius.circular(compact ? 10 : 15),
                ),
                child: Text(
                  'm',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 25 : 38,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          _Bubble(
            left: size - 2,
            top: 0,
            color: _sand,
            diameter: compact ? 8 : 11,
          ),
          _Bubble(
            left: size + 1,
            top: compact ? 13 : 19,
            color: _blue,
            diameter: compact ? 7 : 10,
          ),
          _Bubble(
            left: size - 4,
            top: compact ? 25 : 38,
            color: _sage,
            diameter: compact ? 6 : 9,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.left,
    required this.top,
    required this.color,
    required this.diameter,
  });

  final double left;
  final double top;
  final Color color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
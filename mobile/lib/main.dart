import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mermaid_flutter/mermaid_flutter.dart';

import 'editor_models.dart';
import 'markdown_guide.dart';
import 'preview_segments.dart';

export 'editor_models.dart';
export 'markdown_guide.dart' show GuideItem, GuideKind;

part 'editor_home.dart';
part 'editor_workspace.dart';
part 'markdown_preview.dart';
part 'editor_chrome.dart';

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

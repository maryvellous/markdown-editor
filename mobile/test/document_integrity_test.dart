import 'dart:async';
import 'package:diaspro_markdown_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('dev.diaspro.markdown/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('incoming document cannot discard unsaved edits without confirmation',
      (tester) async {
    Map<String, dynamic>? pending;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'takePendingDocument') {
        final data = pending;
        pending = null;
        return data;
      }
      return null;
    });
    await tester.pumpWidget(const DiasproMarkdownApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bozza da conservare');
    pending = {'uri': 'content://test/other', 'name': 'altro.md', 'content': 'altro'};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Modifiche non salvate'), findsWidgets);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'bozza da conservare');
  });

  testWidgets('save acknowledges its snapshot without replacing later edits',
      (tester) async {
    final save = Completer<Map<String, dynamic>>();
    String? submitted;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createDocument') {
        submitted = (call.arguments as Map)['content'] as String;
        return save.future;
      }
      return null;
    });
    await tester.pumpWidget(const DiasproMarkdownApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'prima versione');
    await tester.tap(find.byTooltip('Salva').first);
    await tester.pump();
    expect(submitted, 'prima versione');
    await tester.enterText(find.byType(TextField), 'modifiche successive');
    save.complete({'uri': 'content://test/saved', 'name': 'salvato.md', 'content': submitted});
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'modifiche successive');
    expect(find.text('Versione precedente salvata; restano modifiche.'), findsOneWidget);
  });
}

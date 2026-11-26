import 'dart:async';
import 'package:diaspro_markdown_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DiasproMarkdownApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bozza da conservare');
    pending = {'uri': 'content://test/other', 'name': 'altro.md', 'content': 'altro'};
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
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
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

  for (final width in [700.0, 800.0, 1280.0]) {
    testWidgets('tablet toolbar fits at ${width.toInt()} logical pixels',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const DiasproMarkdownApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Affianca').hitTestable(), findsOneWidget);
      expect(find.text('Salva con nome').hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Documento modificato');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:diaspro_markdown_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_flutter/mermaid_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.diaspro.markdown/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('fullscreen diagram resets zoom and pan after a fling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DiasproMarkdownApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),
        '\x60\x60\x60mermaid\ngraph TD\n A[Start] --> B[End]\n\x60\x60\x60');
    await tester.tap(find.text('Leggi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tocca per ingrandire'));
    await tester.pumpAndSettle();

    final viewport = find.ancestor(
      of: find.byType(MermaidView),
      matching: find.byType(InteractiveViewer),
    );
    expect(viewport, findsOneWidget);
    expect(find.ancestor(
      of: find.byType(MermaidView),
      matching: find.byType(AbsorbPointer),
    ), findsWidgets);
    final controller =
        tester.widget<InteractiveViewer>(viewport).transformationController!;
    final initial = controller.value.clone();
    // Matrix calculations use floating-point arithmetic; subpixel rounding
    // must not cause a failure, but every scale/translation component is checked.
    void expectInitialTransform() {
      for (var i = 0; i < 16; i++) {
        expect(controller.value.storage[i], closeTo(initial.storage[i], 1e-6),
            reason: 'Transform component $i must return to its initial value');
      }
    }
    final center = tester.getCenter(viewport);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));

    final beforePan = controller.value.clone();
    await tester.flingFrom(center, const Offset(-100, -100), 1200);
    await tester.pump(const Duration(milliseconds: 16));
    final pan = controller.value.getTranslation() - beforePan.getTranslation();
    expect(pan.length, greaterThan(1.0));
    await tester.tap(find.byTooltip('Adatta alla schermata'));
    await tester.pumpAndSettle();
    expectInitialTransform();
    await tester.pump(const Duration(seconds: 2));
    expectInitialTransform();
    expect(tester.takeException(), isNull);
  });
}

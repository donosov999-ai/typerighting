import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/platform_store.dart';
import 'package:typefree_flutter_foundation/main.dart' as app;

/// Real-device smoke (iOS simulator / Android emulator): the real main() with
/// native storage — first-run welcome, profile saved to the platform store,
/// trainer typed key by key with live marks.
/// `flutter test integration_test/ios_smoke_test.dart -d DEVICE_ID`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run → profile persisted natively → trainer typed', (
    tester,
  ) async {
    await app.main();
    await _settle(tester, 3);

    if (find.text('Продолжить').evaluate().isNotEmpty) {
      await tester.tap(find.text('Классический'));
      await _settle(tester, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'Продолжить'));
      await _settle(tester, 1);
    }

    // The choice is in the native store: a fresh repository reads it back.
    final reread = LocalRepository(await openPlatformStore());
    await reread.load();
    expect((reread.data['prefs'] as Map)['profile'], 'm');
    expect(app.needsWelcome(reread.data), false);

    // A phone without a hardware keyboard opens the companion first (source
    // rule); «Всё равно открыть тренажёр →» goes to the trainer anyway.
    final anyway = find.text('Всё равно открыть тренажёр →');
    if (anyway.evaluate().isNotEmpty) {
      await tester.tap(anyway);
      await _settle(tester, 1);
    }
    // A device with a hardware keyboard starts on «Сегодня»: go to the menu.
    if (find.text('Тренировка').evaluate().isEmpty) {
      await tester.tap(find.text('Практика').last);
      await _settle(tester, 1);
    }
    // Practice menu → «Тренировка» → library card «Русские слова».
    await tester.tap(find.text('Тренировка').first);
    await _settle(tester, 1);
    await tester.tap(find.textContaining('Частые слова').first);
    await _settle(tester, 1);
    final input = find.byKey(const ValueKey('practice-input'));
    expect(input, findsOneWidget);
    // Type the first three expected keys one by one, as a person does (the
    // field takes one key per edit).
    final field = tester.widget<TextField>(input);
    var typed = '';
    for (var i = 0; i < 3; i++) {
      final next = _expected(tester);
      typed += next;
      await tester.enterText(input, typed);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(field.controller, isNotNull);
    expect(find.textContaining('100%'), findsWidgets, reason: 'no errors');
    expect(tester.takeException(), isNull);
  });
}

/// Bounded wait: the Synapse face and the cursor animate forever, so
/// pumpAndSettle can hang on a device (Android run 29.10: 31 min).
Future<void> _settle(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The highlighted (expected) character of the lesson line.
String _expected(WidgetTester tester) {
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    String? hit;
    w.text.visitChildren((span) {
      if (span is TextSpan &&
          span.style?.backgroundColor != null &&
          (span.text?.length ?? 0) == 1) {
        hit = span.text;
        return false;
      }
      return true;
    });
    if (hit != null) return hit!;
  }
  throw StateError('no expected key highlighted');
}

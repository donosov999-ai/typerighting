import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// M3: the result shows the saved numbers; «Новый личный рекорд» only when
/// the source rule says so (positive WPM above the bank's saved best).
void main() {
  testWidgets('result card: real numbers, record only when confirmed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) => (d['prefs'] as Map).addAll(<String, dynamic>{'pet': false, 'profile': 'm'}));
    final res = (await tester.runAsync(Resources.load))!;
    final appearance = AppearanceController(res.registry, AppearanceMemory(), existingInstall: true);
    var now = 100000;
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(TypeFreeApp(initialSection: AppSection.practice, key: key, resources: res, repository: repo, appearance: appearance, clock: () => now, phone: false));
    await tester.pump();
    final state = key.currentState!;

    Future<void> runOnce(int stepMs) async {
      var prefix = '';
      await tester.showKeyboard(find.byKey(const ValueKey('practice-input')));
      for (final ch in state.session.pattern.split('')) {
        now += stepMs;
        prefix += ch;
        tester.testTextInput.updateEditingValue(TextEditingValue(text: prefix, selection: TextSelection.collapsed(offset: prefix.length)));
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.saved, true);
    }

    await runOnce(150);
    // M3 on a desktop (sheet 13): one wide card in the main column instead
    // of the keyboard, the three tiles in one row.
    expect(find.byKey(const ValueKey('result-wide')), findsOneWidget);
    final ys = [
      for (final t in ['Скорость', 'Точность', 'Ошибки'])
        tester.getTopLeft(find.descendant(of: find.byKey(const ValueKey('result-wide')), matching: find.text(t))).dy,
    ];
    expect(ys.toSet().length, 1, reason: 'tiles in one row: $ys');
    final wpm = state.session.stats.wpm;
    expect(find.text('Без единой ошибки!'), findsOneWidget);
    expect(find.text('$wpm WPM'), findsWidgets);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Новый личный рекорд!'), findsOneWidget, reason: 'first result beats an empty best');

    // Same exercise again, slower: not a record, no banner.
    await tester.tap(find.text(state.tr('done.again')));
    await tester.pump();
    await tester.pump();
    // The field was disabled under the result: «Заново» must focus it again,
    // or a hardware keyboard types into nothing (seen in the web build).
    expect(FocusManager.instance.primaryFocus, state.inputFocus);
    await runOnce(400);
    expect(state.session.stats.wpm, lessThan(wpm));
    expect(find.text('Новый личный рекорд!'), findsNothing);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

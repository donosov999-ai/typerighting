import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// C1: the banks of the interface language with real counts; filter, search,
/// open in the trainer and come back to the library.
void main() {
  testWidgets('library: real counts, filter, search, open and back', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) {
      (d['prefs'] as Map).addAll(<String, dynamic>{'profile': 'm', 'pet': false});
      (d['legacy'] as Map)['tr_progress_ruWords'] = '{"done":["w1","w2"],"lastIdx":1,"bestWpm":30,"bestAcc":98}';
    });
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: true);
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance, initialSection: AppSection.practiceMenu, phone: false));
    await tester.pump();
    final app = key.currentState!;

    await tester.tap(find.text('Тренировка'));
    await tester.pump();
    expect(app.section, AppSection.library);
    for (final b in ['classic', 'poemHymn', 'ruWords', 'ruPhrases', 'digits']) {
      expect(find.byKey(ValueKey('library-$b')), findsOneWidget, reason: b);
    }
    expect(find.text('22 упражнений · пройдено 2'), findsOneWidget);
    expect(find.text('50 упражнений'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Цифры'));
    await tester.pump();
    expect(find.byKey(const ValueKey('library-digits')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-ruWords')), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Все'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'фраз');
    await tester.pump();
    expect(find.byKey(const ValueKey('library-ruPhrases')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-classic')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('library-ruPhrases')));
    await tester.pump();
    expect(app.section, AppSection.practice);
    expect(app.bank, 'ruPhrases');
    expect(app.index, 0);
    await tester.tap(find.byTooltip('← Назад'));
    await tester.pump();
    expect(app.section, AppSection.library);

    // Other languages list only their own banks.
    await app.changeLanguage('en');
    await tester.pump();
    expect(find.byKey(const ValueKey('library-ruWords')), findsNothing);
    expect(find.byKey(const ValueKey('library-classic')), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

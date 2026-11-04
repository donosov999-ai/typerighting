import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// Group 11 (FUNCTION_PARITY): «Только цифры» off returns to the text bank
/// that was active before, and that bank is saved (prefs.textBank).
void main() {
  testWidgets(
    'custom text is not advertised as numbers-only and digits can be resumed',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final resources = (await tester.runAsync(Resources.load))!;
      final repo = LocalRepository(MemoryStore());
      await repo.transaction(
        (d) => (d['prefs'] as Map).addAll(<String, dynamic>{
          'pet': false,
          'profile': 'm',
          'lang': 'ru',
          'bank': 'digits',
          'textBank': 'ruWords',
        }),
      );
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: true,
      );
      final key = GlobalKey<TypeFreeAppState>();
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          resources: resources,
          repository: repo,
          initialSection: AppSection.practice,
          phone: false,
          appearance: appearance,
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Только цифры'),
            )
            .value,
        true,
      );
      await tester.tap(find.text('Свой текст'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'мой текст');
      await tester.pump();
      await tester.tap(find.text(key.currentState!.tr('custom.start')));
      await tester.pumpAndSettle();
      expect(key.currentState!.session.pattern, contains('мой текст'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Только цифры'),
            )
            .value,
        false,
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Только цифры'));
      await tester.pumpAndSettle();
      expect(key.currentState!.custom, isNull);
      expect(key.currentState!.bank, 'digits');
      expect(
        RegExp(r'^[0-9\s]+$').hasMatch(key.currentState!.session.pattern),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    },
  );
  testWidgets('digits-only catalog does not offer a nonfunctional exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final full = (await tester.runAsync(Resources.load))!;
    final content = Map<String, dynamic>.from(full.content);
    content['catalog'] = {
      for (final entry in (full.content['catalog'] as Map).entries)
        entry.key: [
          for (final row in entry.value as List)
            if ((row as Map)['bank'] == 'digits') row,
        ],
    };
    final resources = Resources(
      content,
      full.keyboards,
      full.registry,
      full.course,
      full.learning,
      full.kids,
    );
    final repo = LocalRepository(MemoryStore());
    await repo.transaction(
      (d) => (d['prefs'] as Map).addAll(<String, dynamic>{
        'pet': false,
        'profile': 'm',
        'lang': 'ru',
        'bank': 'digits',
      }),
    );
    final appearance = AppearanceController(
      full.registry,
      AppearanceMemory(),
      existingInstall: true,
    );
    await tester.pumpWidget(
      TypeFreeApp(
        resources: resources,
        repository: repo,
        initialSection: AppSection.practice,
        phone: false,
        appearance: appearance,
      ),
    );
    await tester.pump();
    final checkbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Только цифры'),
    );
    expect(checkbox.value, true);
    expect(checkbox.onChanged, isNull);
    tester.view.physicalSize = const Size(700, 900);
    await tester.pump();
    final chip = tester.widget<InputChip>(
      find.widgetWithText(InputChip, 'Только цифры'),
    );
    expect(chip.onDeleted, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
  });
  testWidgets(
    'older numeric preference can return to a text bank after restart',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final resources = (await tester.runAsync(Resources.load))!;
      final repo = LocalRepository(MemoryStore());
      await repo.transaction((d) {
        (d['prefs'] as Map).addAll(<String, dynamic>{
          'pet': false,
          'profile': 'm',
          'lang': 'ru',
          'bank': 'digits',
        });
      });
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: true,
      );
      final key = GlobalKey<TypeFreeAppState>();
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          resources: resources,
          repository: repo,
          initialSection: AppSection.practice,
          phone: false,
          appearance: appearance,
        ),
      );
      await tester.pump();
      expect(key.currentState!.bank, 'digits');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Только цифры'));
      await tester.pumpAndSettle();
      expect(key.currentState!.bank, isNot('digits'));
      expect(key.currentState!.exercises, isNotEmpty);
      expect((repo.data['prefs'] as Map)['textBank'], isNot('digits'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    },
  );
  testWidgets('digits off restores the previous text bank', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction(
      (d) => (d['prefs'] as Map).addAll(<String, dynamic>{
        'pet': false,
        'profile': 'm',
        'lang': 'ru',
        'bank': 'ruWords',
      }),
    );
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(
      TypeFreeApp(
        key: key,
        resources: resources,
        repository: repo,
        initialSection: AppSection.practice,
        phone: false,
        appearance: AppearanceController(
          resources.registry,
          AppearanceMemory(),
          existingInstall: true,
        ),
      ),
    );
    await tester.pump();
    final app = key.currentState!;
    Future<void> toggleDigits() async {
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Только цифры'));
      await tester.pumpAndSettle();
    }

    expect(app.bank, 'ruWords');
    await toggleDigits();
    expect(app.bank, 'digits');
    await toggleDigits();
    expect(app.bank, 'ruWords');

    app.openBank('classic');
    await tester.pumpAndSettle();
    expect(app.bank, 'classic');
    await toggleDigits();
    await toggleDigits();
    expect(app.bank, 'classic');
    expect((repo.data['prefs'] as Map)['textBank'], 'classic');
    expect(tester.takeException(), isNull);
  });
}

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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// Narrow trainer: options sit in a «Параметры» sheet; an action that leaves
/// the options (custom text, weak keys) closes the sheet first.
void main() {
  testWidgets('options sheet closes before «Свой текст» and «Слабые клавиши»', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) => (d['prefs'] as Map).addAll(<String, dynamic>{'profile': 'm', 'pet': false}));
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: true);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance, initialSection: AppSection.practice, phone: false));
    await tester.pump();

    await tester.tap(find.byTooltip('Параметры'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Свой текст'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Параметры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(key.currentState!.tr('tb.weak')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(key.currentState!.weakMode, true);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

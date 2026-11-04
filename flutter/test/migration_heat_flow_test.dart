import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/webview_migration.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/weak_keys_page.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

void main() {
  testWidgets('imported missing key appears on the actual weak-keys screen', (
    tester,
  ) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.transaction((d) {
      (d['prefs'] as Map).addAll(<String, dynamic>{
        'lang': 'en',
        'pet': false,
        'motion': false,
      });
      (d['legacy'] as Map)['tr_keystats'] = '{"a":{"ok":7,"err":1}}';
    });
    await importWebviewValues(repo, {
      'tr_keystats': '{"a":{"ok":20,"err":5},"b":{"ok":1,"err":9}}',
    });
    final restarted = LocalRepository(store);
    await restarted.load();
    final appearance = AppearanceController(
      resources.registry,
      AppearanceMemory(),
      existingInstall: false,
    );
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(
      TypeFreeApp(
        initialSection: AppSection.weakKeys,
        resources: resources,
        repository: restarted,
        appearance: appearance,
      ),
    );
    await tester.pump();
    final heat = tester
        .widget<CompactHeatMap>(find.byType(CompactHeatMap))
        .heat;
    expect(heat['b'], closeTo(.9, .001));
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('B')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

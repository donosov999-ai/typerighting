import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// F2: earned badges come from history (source rules), locked ones show real
/// progress, unknown old badge ids are preserved and listed.
void main() {
  testWidgets('F2 achievements: earned, progress to locked, tabs, archived ids', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) {
      (d['prefs'] as Map)['pet'] = false;
      final legacy = d['legacy'] as Map;
      legacy['tr_history'] = jsonEncode([
        {'t': 1000, 'wpm': 22, 'acc': 95},
        {'t': 2000, 'wpm': 35, 'acc': 99},
      ]);
      legacy['tr_ach'] = jsonEncode(['first', 'oldbadge']);
    });
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: true);
    final key = GlobalKey<TypeFreeAppState>();
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance));
    await tester.pump();
    final app = key.currentState!;

    await app.showSection(AppSection.more);
    await tester.pump();
    await tester.tap(find.text('Достижения'));
    await tester.pump();
    expect(app.section, AppSection.achievements);

    // first + wpm30 + acc99 of the 11 source badges.
    expect(find.text('3 / 11'), findsOneWidget);
    expect(find.bySemanticsLabel('Первые шаги · Получено'), findsOneWidget);
    expect(find.bySemanticsLabel('Точность 99% · Получено'), findsOneWidget);
    expect(find.bySemanticsLabel('10 сессий · 2 / 10'), findsOneWidget);
    expect(find.bySemanticsLabel('50 WPM · 35 / 50'), findsOneWidget);
    expect(find.textContaining('oldbadge'), findsOneWidget);

    await tester.tap(find.text('Получены'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel(RegExp('· Получено\$')), findsNWidgets(3));
    await tester.tap(find.text('Закрыты'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNWidgets(8));

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

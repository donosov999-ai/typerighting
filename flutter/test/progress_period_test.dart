import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/progress_page.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// F1 (sheet 06): the chart has «7 дней / 30 дней / Всё время»; the default
/// is 7 days, falling back to all time when the last week has < 2 sessions;
/// «Последние тренировки» comes right after the tiles, before the extras.
void main() {
  const day = 86400000, now = 100 * day;
  Future<LocalRepository> repoWith(List<int> daysAgo) async {
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    for (var i = 0; i < daysAgo.length; i++) {
      await repo.appendSession({
        'id': 's-$i',
        'title': 'Русские слова',
        'exercise': 'ruw-1',
        'language': 'ru',
        'profile': 'm',
        'mode': 'practice',
        'difficulty': 'ruWords/1/false',
        't': now - daysAgo[i] * day,
        'wpm': 30 + i,
        'accuracy': 95,
        'errors': 1,
        'elapsedMs': 2000,
      });
    }
    return repo;
  }

  Future<void> show(WidgetTester tester, LocalRepository repo) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final theme = AppearanceController(
      resources.registry,
      AppearanceMemory(),
      existingInstall: true,
    ).theme(Brightness.dark);
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressPage(
              repository: repo,
              profile: 'm',
              language: 'ru',
              tr: (k) => k,
              onWeak: () {},
              clock: () => now,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String c(String k) => progressCopy('ru', k);

  testWidgets('7 days by default, switch to all time', (tester) async {
    await show(tester, await repoWith([20, 15, 3, 2, 1]));
    expect(find.text(c('days7')), findsOneWidget);
    expect(find.textContaining('prog.sessions: 3 '), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('progress-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c('allTime')).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('prog.sessions: 5 '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiet week falls back to all time; recent before extras', (
    tester,
  ) async {
    await show(tester, await repoWith([40, 30, 20]));
    expect(find.text(c('allTime')), findsOneWidget);
    expect(find.textContaining('prog.sessions: 3 '), findsOneWidget);
    final recent = tester.getTopLeft(find.text(c('recent'))).dy;
    final target = tester.getTopLeft(find.byKey(const ValueKey('progress-target'))).dy;
    expect(recent, lessThan(target), reason: 'sheet 06 order');
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/artifact_export.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/legacy_transfer.dart';
import 'package:typefree_flutter_foundation/data/webview_migration.dart';
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

  Future<void> show(
    WidgetTester tester,
    LocalRepository repo, {
    ArtifactExporter? exporter,
    bool migrationPending = false,
  }) async {
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
              exporter: exporter,
              migrationPending: migrationPending,
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

  testWidgets('certificate recovery keeps copies and applies only the selected profile', (tester) async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    await importWebviewValues(repo, {'tr_name': 'Previous name', 'tr_profile': 'm'});
    await repo.transaction((d) => (d['prefs'] as Map).remove(webviewMigrationFlag));
    await importWebviewValues(repo, {'tr_name': 'Another name'});
    await show(tester, repo, migrationPending: true);
    await tester.tap(find.byKey(const ValueKey('progress-name-recovery')));
    await tester.pumpAndSettle();
    expect(find.text('Previous name'), findsOneWidget);
    expect(find.text('Another name'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recovery-use-name-1')));
    await tester.pumpAndSettle();
    final reloaded = LocalRepository(store);
    await reloaded.load();
    expect(reloaded.data['prefs']['certificateName_m'], 'Another name');
    expect(reloaded.data['prefs']['legacyCertificateName'], 'Previous name');
    expect(reloaded.data['prefs']['webviewNameCopies'], ['Another name']);
    expect(reloaded.data['prefs']['certificateName_f'], isNull);
    expect(needsWebviewMigration(reloaded.data), true);
    for (final lang in ['ru','en','es','de','fr','it','pt']) {
      expect(progressCopy(lang, 'nameRecoveryTitle'), isNot('nameRecoveryTitle'));
    }
  });

  testWidgets(
    'incomplete mobile migration warns that progress may be incomplete',
    (tester) async {
      final repo = await repoWith([]);
      await show(tester, repo, migrationPending: true);
      expect(
        find.byKey(const ValueKey('progress-migration-pending')),
        findsOneWidget,
      );
      expect(find.text(c('migrationPending')), findsOneWidget);
      expect(
        (repo.data['prefs'] as Map).containsKey('webviewMigration'),
        isFalse,
      );
      for (final lang in ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt']) {
        expect(
          progressCopy(lang, 'migrationPending'),
          isNot('migrationPending'),
        );
      }
    },
  );

  testWidgets(
    'home shows incomplete migration and opens progress in both templates',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      for (final template in ['classic-blue', 'midnight-speed-v1']) {
        final repo = await repoWith([]);
        final appearance = AppearanceController(
          resources.registry,
          AppearanceMemory(),
          existingInstall: true,
        )..preview(template, ThemeMode.dark);
        final key = GlobalKey<TypeFreeAppState>();
        await tester.pumpWidget(
          TypeFreeApp(
            key: key,
            resources: resources,
            repository: repo,
            appearance: appearance,
            initialSection: AppSection.today,
            migrationPending: true,
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('home-migration-pending')),
          findsOneWidget,
        );
        final action = find.byKey(const ValueKey('home-migration-open'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        expect(key.currentState!.section, AppSection.progress);
        expect(
          find.byKey(const ValueKey('progress-migration-pending')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        appearance.dispose();
      }
    },
  );

  testWidgets('app passes pending migration state to progress', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = await repoWith([]);
    final appearance = AppearanceController(
      resources.registry,
      AppearanceMemory(),
      existingInstall: true,
    );
    await tester.pumpWidget(
      TypeFreeApp(
        resources: resources,
        repository: repo,
        appearance: appearance,
        initialSection: AppSection.progress,
        migrationPending: true,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('progress-migration-pending')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
  });

  testWidgets('history displays readable mode and language labels', (
    tester,
  ) async {
    final repo = await repoWith([0]);
    await show(tester, repo);
    expect(find.textContaining('Русский · Тренировка'), findsOneWidget);
    for (final lang in ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt']) {
      for (final mode in [
        'practice',
        'weak',
        'course',
        'learn',
        'compete',
        'memorize',
        'recall',
        'exam',
      ]) {
        expect(progressModeLabel(lang, mode), isNotEmpty);
        expect(progressModeLabel(lang, mode), isNot(mode));
      }
    }
    expect(progressModeLabel('ru', 'future-mode'), 'future-mode');
  });

  testWidgets('long history loads more rows without changing statistics', (
    tester,
  ) async {
    final repo = await repoWith(List.generate(25, (i) => i));
    await show(tester, repo);
    expect(find.text('30 WPM'), findsOneWidget);
    expect(find.text('54 WPM'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('progress-stat-sessions')),
        matching: find.text('25'),
      ),
      findsOneWidget,
    );
    final more = find.byKey(const ValueKey('progress-show-more'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    expect(find.text('54 WPM'), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-show-more')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('progress-stat-sessions')),
        matching: find.text('25'),
      ),
      findsOneWidget,
    );
    expect((repo.data['sessions'] as List).length, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart accessibility summary pairs each date with its results', (
    tester,
  ) async {
    final repo = await repoWith([0, 1]);
    await show(tester, repo);
    final summary = tester
        .widget<Semantics>(find.byKey(const ValueKey('progress-chart-summary')))
        .properties
        .label!;
    expect(summary, contains('31 WPM'));
    expect(summary, contains('30 WPM'));
    expect(summary, contains('95%'));
    expect(summary.split('; ').length, 2);
    final date = DateTime.fromMillisecondsSinceEpoch(now - day).toLocal();
    expect(
      summary,
      contains(
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
      ),
    );
    expect(summary.indexOf('31 WPM'), lessThan(summary.indexOf('30 WPM')));
  });

  testWidgets('compact graph leaves room for large text', (tester) async {
    final repo = await repoWith([0, 1]);
    await show(tester, repo);
    expect(
      tester.getSize(find.byKey(const ValueKey('progress-chart'))).height,
      132,
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('progress-chart'))).height,
      200,
    );
    expect(find.byKey(const ValueKey('progress-period')), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('progress summary cards have equal height in a row', (
    tester,
  ) async {
    final repo = await repoWith([0, 1]);
    await show(tester, repo);
    final rectangles = [
      for (final name in ['streak', 'sessions', 'best'])
        tester.getRect(find.byKey(ValueKey('progress-stat-$name'))),
    ];
    expect(rectangles.map((r) => r.height).toSet().length, 1);
    expect(rectangles.map((r) => r.top).toSet().length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ineligible short exam remains visible but not in totals or best',
    (tester) async {
      final repo = await repoWith([1]);
      await repo.appendSession({
        'id': 'short-exam',
        'title': 'Short exam',
        'exercise': 'exam',
        'language': 'ru',
        'profile': 'm',
        'mode': 'exam',
        'difficulty': 'exam',
        't': now,
        'wpm': 200,
        'accuracy': 100,
        'errors': 0,
        'elapsedMs': 1000,
        'len': 4,
        'historyEligible': false,
      });
      await show(tester, repo);
      expect(find.text('Short exam'), findsOneWidget);
      expect(find.text('200 WPM'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // streak and eligible sessions
      expect(find.text('200'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery notice and export remain reachable in seven languages at large text',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: true,
      );
      await tester.binding.setSurfaceSize(const Size(320, 700));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      for (final language in languages) {
        final repo = await repoWith([]);
        await repo.transaction(
          (doc) =>
              (doc['legacy'] as Map)['tr_keystats'] = '{"a":{"ok":1,"err":2}}',
        );
        await importWebviewValues(repo, {
          'tr_keystats': '{"a":{"ok":3,"err":4}}',
          'tr_history': '{broken',
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: appearance.theme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProgressPage(
                  key: ValueKey(language),
                  repository: repo,
                  profile: 'm',
                  language: language,
                  tr: (k) => k,
                  onWeak: () {},
                  exporter: (_, _, _) async => ArtifactExportOutcome.cancelled,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('progress-recovery-invalid')),
          findsOneWidget,
          reason: language,
        );
        final expansion = find.byKey(const ValueKey('progress-recovery'));
        await tester.ensureVisible(expansion);
        await tester.pump();
        await tester.tap(expansion);
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('recovery-export-0'));
        await tester.ensureVisible(button);
        await tester.pump();
        expect(button.hitTestable(), findsOneWidget, reason: language);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.text(progressCopy(language, 'cancelled')),
          findsOneWidget,
          reason: language,
        );
        expect(tester.takeException(), isNull, reason: language);
        await tester.pumpWidget(const SizedBox());
      }
      appearance.dispose();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'export recovery copy keeps conflict data and excludes private keys',
    (tester) async {
      final repo = await repoWith([]);
      await repo.transaction(
        (d) => (d['legacy'] as Map)['tr_keystats'] = '{"a":{"ok":1,"err":2}}',
      );
      await importWebviewValues(repo, {
        'tr_keystats': '{"a":{"ok":4,"err":9}}',
        'tr_account_pin': 'private',
      });
      Map<String, dynamic>? exported;
      await show(
        tester,
        repo,
        exporter: (name, bytes, mime) async {
          expect(name, startsWith('TypeFree-recovery-'));
          exported = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          return ArtifactExportOutcome.saved;
        },
      );
      await tester.tap(find.byKey(const ValueKey('progress-recovery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recovery-export-0')));
      await tester.pumpAndSettle();
      expect(verifyTransfer(exported!), {
        'tr_keystats': '{"a":{"ok":4,"err":9}}',
      });
      expect(jsonEncode(exported).contains('private'), false);
      expect(find.text(c('saved')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid old history displays incomplete progress notice', (
    tester,
  ) async {
    final repo = await repoWith([]);
    await importWebviewValues(repo, {'tr_history': '{broken'});
    await show(tester, repo);
    expect(
      find.byKey(const ValueKey('progress-recovery-invalid')),
      findsOneWidget,
    );
    expect(find.text(c('recoveryInvalid')), findsOneWidget);
    expect(find.textContaining('{broken'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    final target = tester
        .getTopLeft(find.byKey(const ValueKey('progress-target')))
        .dy;
    expect(recent, lessThan(target), reason: 'sheet 06 order');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending history is visible separately without changing totals', (
    tester,
  ) async {
    final repo = await repoWith([]);
    await repo.transaction((d) {
      (d['legacy'] as Map)['tr_history'] = '[]';
      (d['legacyArchive'] as Map)['tr_history'] = '[]';
    });
    await importWebviewValues(repo, {
      'tr_history': '[{"t":86400000,"wpm":42,"acc":97}]',
    });
    await show(tester, repo);
    expect(find.text(c('recoveryTitle')), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('progress-recovery')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${c('recoveryCopy')} 1 · 1'));
    await tester.pumpAndSettle();
    expect(find.text(c('oldSession')), findsOneWidget);
    expect(find.textContaining('42'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('history export includes unresolved history separately but excludes settings', () async {
    final repo = await repoWith([]);
    await repo.transaction((d) {
      (d['legacy'] as Map)['tr_history'] = '[]';
      (d['legacyArchive'] as Map)['tr_history'] = '[]';
      (d['legacy'] as Map)['tr_lang'] = 'en';
    });
    await importWebviewValues(repo, {
      'tr_history': '[{"t":86400000,"wpm":42,"acc":97}]',
      'tr_lang': 'ru',
      'tr_account_pin': '1234',
    });
    Map<String, dynamic>? result;
    await exportHistory(repo, (name, bytes, mime) async {
      result = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return ArtifactExportOutcome.saved;
    }, now);
    expect(result!['sessions'], isEmpty);
    expect(result!['unresolvedHistoryCopies'], [
      [
        {'t': 86400000, 'wpm': 42, 'acc': 97},
      ],
    ]);
    expect(jsonEncode(result).contains('tr_lang'), false);
    expect(jsonEncode(result).contains('1234'), false);
  });
}

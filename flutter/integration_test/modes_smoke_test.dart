import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/platform_store.dart';
import 'package:typefree_flutter_foundation/features/competition_page.dart';
import 'package:typefree_flutter_foundation/features/course_page.dart';
import 'package:typefree_flutter_foundation/features/exam_page.dart';
import 'package:typefree_flutter_foundation/features/kids_page.dart';
import 'package:typefree_flutter_foundation/features/learning_page.dart';
import 'package:typefree_flutter_foundation/features/memorize_page.dart';
import 'package:typefree_flutter_foundation/features/recall_page.dart';
import 'package:typefree_flutter_foundation/main.dart' as app;

/// All modes on a real device (iOS simulator / Android emulator) with the
/// real main() and native storage: from the speed home each mode is opened,
/// started and typed with the expected keys; the engine must advance. The
/// typing test is finished early and its result must be in the native store
/// after a fresh read. Prints a table «mode · opened · typed · note».
/// `flutter test integration_test/modes_smoke_test.dart -d DEVICE_ID`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every mode opens, starts and takes real keys', (tester) async {
    await app.main();
    await _settle(tester, 3);
    if (find.text('Продолжить').evaluate().isNotEmpty) {
      await tester.tap(find.text('Классический'));
      await _settle(tester, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'Продолжить'));
      await _settle(tester, 1);
    }
    final anyway = find.text('Всё равно открыть тренажёр →');
    if (anyway.evaluate().isNotEmpty) {
      await tester.tap(anyway);
      await _settle(tester, 1);
    }
    final shell = tester.state<app.TypeFreeAppState>(
      find.byType(app.TypeFreeApp),
    );
    final rows = <String>[];
    final failed = <String>[];

    Future<void> home() async {
      await shell.showSection(app.AppSection.today);
      await _settle(tester, 1);
    }

    Future<void> openMode(int i) async {
      await home();
      final card = find.byKey(
        ValueKey('home-mode-${shell.modeEntries[i].title}'),
      );
      await tester.ensureVisible(card);
      await tester.tap(card);
      await _settle(tester, 1);
    }

    Future<int> type(Finder input, String Function() expected, int n) async {
      await tester.ensureVisible(input);
      await tester.tap(input);
      var text = tester.widget<TextField>(input).controller?.text ?? '';
      for (var k = 0; k < n; k++) {
        text += expected();
        await tester.enterText(input, text);
        await tester.pump(const Duration(milliseconds: 150));
      }
      return n;
    }

    Future<void> check(
      String mode,
      Future<void> Function() open,
      Future<int> Function() typed,
    ) async {
      var opened = false, ok = false;
      var note = '';
      try {
        await open();
        opened = true;
        ok = await typed() > 0;
      } catch (e) {
        note = '$e'.split('\n').first;
      }
      final ex = tester.takeException();
      if (ex != null) note = 'exception: ${'$ex'.split('\n').first}';
      rows.add(
        '$mode · opened=$opened · typed=$ok${note.isEmpty ? '' : ' · $note'}',
      );
      if (!opened || !ok || note.isNotEmpty) failed.add(mode);
    }

    // 0 Тренировка: «Начать печатать» → the practice field.
    await check(
      'practice',
      () async {
        await home();
        await tester.tap(find.byKey(const ValueKey('home-start')));
        await _settle(tester, 1);
      },
      () async {
        final before = shell.session.pos;
        await type(
          find.byKey(const ValueKey('practice-input')),
          () => shell.session.expected!,
          3,
        );
        return shell.session.pos - before;
      },
    );

    // 1 Курс печати: lesson 1.
    await check(
      'course',
      () async {
        await openMode(1);
        await tester.ensureVisible(
          find.byKey(const ValueKey('course-lesson-1')),
        );
        await tester.tap(find.byKey(const ValueKey('course-lesson-1')));
        await _settle(tester, 1);
      },
      () async {
        final page = tester.state<CoursePageState>(find.byType(CoursePage));
        final s = page.attempt!.session;
        await type(
          find.byKey(const ValueKey('course-input')),
          () => s.expected!,
          3,
        );
        return s.pos;
      },
    );

    // 2 AI-обучение.
    await check('learn', () => openMode(2), () async {
      final page = tester.state<LearningPageState>(find.byType(LearningPage));
      await type(
        find.byKey(const ValueKey('learning-input')),
        () => page.engine.typing.expected!,
        3,
      );
      return page.engine.typing.pos;
    });

    // 3 Соревнование: alphabet forward.
    await check(
      'compete',
      () async {
        await openMode(3);
        final d = find.byKey(const ValueKey('competition-alpha_fwd'));
        await tester.ensureVisible(d);
        await tester.tap(d);
        await _settle(tester, 1);
      },
      () async {
        final page = tester.state<CompetitionPageState>(
          find.byType(CompetitionPage),
        );
        await type(
          find.byKey(const ValueKey('competition-input')),
          () => page.engine!.typing.expected!,
          3,
        );
        return page.engine!.typing.pos;
      },
    );

    // 4 Наизусть: classic source, first piece.
    await check(
      'memorize',
      () async {
        await openMode(4);
        await tester.ensureVisible(
          find.byKey(const ValueKey('memorize-source-classic')),
        );
        await tester.tap(find.byKey(const ValueKey('memorize-source-classic')));
        await _settle(tester, 1);
        await tester.ensureVisible(
          find.byKey(const ValueKey('memorize-piece-0')),
        );
        await tester.tap(find.byKey(const ValueKey('memorize-piece-0')));
        await _settle(tester, 1);
      },
      () async {
        final page = tester.state<MemorizePageState>(find.byType(MemorizePage));
        await type(
          find.byKey(const ValueKey('memorize-input')),
          () => page.engine!.typing.expected!,
          3,
        );
        return page.engine!.typing.pos;
      },
    );

    // 5 Память: start, wait for the words to hide, type.
    await check(
      'recall',
      () async {
        await openMode(5);
        final start = find.byKey(const ValueKey('recall-start'));
        await tester.ensureVisible(start);
        await tester.tap(start);
        await _settle(tester, 6);
      },
      () async {
        final page = tester.state<RecallPageState>(find.byType(RecallPage));
        final run = page.engine!;
        await type(
          find.byKey(const ValueKey('recall-input')),
          () => run.typing.expected!,
          3,
        );
        return run.typing.pos;
      },
    );

    // 6 Тест печати: name, start, 3 keys, early finish → native store.
    await check(
      'exam',
      () async {
        await openMode(6);
        await tester.enterText(
          find.byKey(const ValueKey('exam-name')),
          'Smoke',
        );
        await _settle(tester, 1);
        final start = find.byKey(const ValueKey('exam-start'));
        await tester.ensureVisible(start);
        await tester.tap(start);
        await _settle(tester, 1);
      },
      () async {
        final page = tester.state<ExamPageState>(find.byType(ExamPage));
        await type(
          find.byKey(const ValueKey('exam-input')),
          () => page.engine!.typing.expected!,
          12,
        );
        final finish = find.byKey(const ValueKey('exam-finish'));
        await tester.ensureVisible(finish);
        await tester.tap(finish);
        await _settle(tester, 2);
        final reread = LocalRepository(await openPlatformStore());
        await reread.load();
        final saved = (reread.data['sessions'] as List).where(
          (r) => (r as Map)['mode'] == 'exam',
        );
        return saved.isEmpty ? 0 : 1;
      },
    );

    // 7 Детский режим: level 1.
    await check(
      'kids',
      () async {
        await openMode(7);
        final level = find.byKey(const ValueKey('kids-level-1'));
        await tester.ensureVisible(level);
        await tester.tap(level);
        await _settle(tester, 1);
      },
      () async {
        final page = tester.state<KidsPageState>(find.byType(KidsPage));
        final all = page.engine.level!.words.join();
        var i = 0;
        await type(find.byKey(const ValueKey('kids-input')), () => all[i++], 3);
        return i;
      },
    );

    // ignore: avoid_print
    print('MODES\n${rows.join('\n')}');
    expect(failed, isEmpty, reason: rows.join('\n'));
  });
}

/// Bounded wait: Synapse and the cursor animate forever (pumpAndSettle hung
/// 31 min on Android 29.10).
Future<void> _settle(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

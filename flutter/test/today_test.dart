import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/domain/today.dart';
import 'package:typefree_flutter_foundation/features/course_page.dart';
import 'package:typefree_flutter_foundation/features/today_page.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

void main() {
  test('day streak uses distinct local dates/current profile; course continuation uses actual stars', () {
    final now = DateTime(2026, 10, 25, 18);
    Map<String, dynamic> row(int day, String profile, int wpm) => {
      't': DateTime(2026, 10, day, 12).millisecondsSinceEpoch,
      'profile': profile,
      'wpm': wpm,
      'accuracy': 98,
    };
    final doc = LocalRepository(MemoryStore()).data;
    doc['sessions'] = [
      row(25, 'm', 45),
      row(25, 'm', 48),
      row(24, 'm', 42),
      row(23, 'f', 99),
    ];
    (doc['legacy'] as Map)['tr_course_ru'] = '{"stars":{"1":3}}';
    final before = jsonEncode(doc);
    final s = TodaySummary(
      doc,
      profile: 'm',
      language: 'ru',
      now: now,
      lessonCount: 19,
    );
    expect(s.streak, 2);
    expect(s.latest!['wpm'], 45);
    expect(s.completed, 1);
    expect(s.nextLesson, 2);
    expect(s.progress, 1 / 19);
    expect(jsonEncode(doc), before);
    final stale = TodaySummary(
      doc,
      profile: 'm',
      language: 'en',
      now: DateTime(2026, 10, 27),
      lessonCount: 19,
    );
    expect(stale.streak, 0);
    expect(stale.progress, 0);
  });
  test('legacy records with unknown profile do not become a current-profile streak or latest result', () {
    final doc = LocalRepository(MemoryStore()).data;
    doc['legacyArchive'] = {'tr_history': '[{"t":1,"wpm":99,"acc":100}]'};
    final s = TodaySummary(
      doc,
      profile: 'm',
      language: 'ru',
      now: DateTime(2026, 10, 25),
      lessonCount: 19,
    );
    expect(s.latest, isNull);
    expect(s.streak, 0);
    expect(s.nextLesson, 1);
    (doc['legacy'] as Map)['tr_course_ru'] = jsonEncode({
      'stars': {for (var i = 1; i <= 19; i++) '$i': 3},
    });
    final finished = TodaySummary(
      doc,
      profile: 'm',
      language: 'ru',
      now: DateTime(2026, 10, 25),
      lessonCount: 19,
    );
    expect(finished.progress, 1);
    expect(finished.nextLesson, 1);
  });
  testWidgets(
    'Today is default, fits a narrow window, opens real practice and continues actual course',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      final repo = LocalRepository(MemoryStore());
      await repo.load();
      await repo.transaction((d) {
        (d['prefs'] as Map)['pet'] = false;
        (d['legacy'] as Map)['tr_course_ru'] = '{"stars":{"1":3}}';
      });
      final before = repo.data;
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: false,
      );
      final key = GlobalKey<TypeFreeAppState>();
      await tester.binding.setSurfaceSize(const Size(320, 582));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          resources: resources,
          repository: repo,
          appearance: appearance,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('today-hero')), findsOneWidget);
      expect(find.text('Начать тренировку'), findsOneWidget);
      expect(find.text('Продолжить курс'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
      expect(repo.data, before);
      expect(
        tester.getRect(find.byKey(const ValueKey('today-course'))).bottom,
        lessThan(526),
      );
      expect(tester.takeException(), isNull);
      final id = key.currentState!.sessionId;
      await tester.tap(find.text('Начать тренировку'));
      await tester.pump();
      expect(find.byKey(const ValueKey('practice-input')), findsOneWidget);
      expect(key.currentState!.sessionId, id);
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('today-course')));
      await tester.pump();
      await tester.pump();
      final course = tester.state<CoursePageState>(find.byType(CoursePage));
      expect(course.lesson!['id'], 2);
      expect(course.attempt, isNotNull);
      expect(repo.data, before);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.tap(find.text('Настройки'));
      await tester.pump();
      expect(find.text('Настройки ввода'), findsOneWidget);
      await tester.tap(find.text('Звук и оформление'));
      await tester.pump();
      expect(find.text('Шаблон'), findsOneWidget);
      await tester.tap(find.byTooltip('← Назад'));
      await tester.pump();
      expect(find.text('Настройки ввода'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'Today remains readable in all seven languages with enlarged text and both templates',
    (tester) async {
      final res = (await tester.runAsync(Resources.load))!;
      await tester.binding.setSurfaceSize(const Size(320, 582));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt']) {
        final repo = LocalRepository(MemoryStore());
        await repo.load();
        await repo.transaction((d) {
          (d['prefs'] as Map).addAll(<String, dynamic>{
            'lang': language,
            'pet': false,
          });
        });
        final appearance = AppearanceController(
          res.registry,
          AppearanceMemory(),
          existingInstall: false,
        );
        appearance.preview(
          language == 'ru' ? 'classic-blue' : 'midnight-orange',
          ThemeMode.dark,
        );
        await appearance.apply();
        await tester.pumpWidget(
          TypeFreeApp(
            key: ValueKey(language),
            resources: res,
            repository: repo,
            appearance: appearance,
          ),
        );
        await tester.pump();
        expect(find.text(shellText(language, 'start')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: language);
        await tester.ensureVisible(find.byKey(const ValueKey('today-course')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: language);
        await tester.pumpWidget(const SizedBox());
        appearance.dispose();
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}

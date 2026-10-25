import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/course.dart';
import 'package:typefree_flutter_foundation/features/course_page.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

void main() {
  final data = jsonDecode(
    File('assets/baseline/course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final fixtures = jsonDecode(
    File('test/fixtures/course-generation.json').readAsStringSync(),
  ) as Map;
  test('all 133 course generators match shipped TypeScript with the same random stream', () {
    for (final c in fixtures['cases'] as List) {
      var seed = 1943;
      int random(int n) {
        seed = (seed * 1664525 + 1013904223) & 0xffffffff;
        return (seed / 4294967296 * n).floor();
      }

      expect(
        CourseGenerator(data, random).lines(
          c['language'] as String,
          Map<String, dynamic>.from(c['lesson'] as Map),
        ),
        c['lines'],
        reason: '${c['language']}/${c['lesson']['id']}',
      );
    }
    for (final c in fixtures['stars'] as List) {
      expect(courseStars(c['errors'] as int, c['chars'] as int), c['stars']);
    }
    expect(courseUnlocked(1, {}), true);
    expect(courseUnlocked(2, {}), false);
    expect(courseUnlocked(2, {'1': 1}), true);
  });
  test('per-line advance, blocked mistakes and lesson stars preserve old course rules', () {
    var t = 1000;
    final a = CourseAttempt(['ab', 'cd'], clock: () => t);
    a.press('x');
    t += 100;
    a.press('a');
    t += 100;
    expect(a.press('b'), true);
    expect(a.line, 1);
    expect(a.errors, 1);
    expect(a.session.pos, 0);
    t += 100;
    a.press('c');
    t += 100;
    a.press('d');
    expect(a.finished, true);
    expect(a.characters, 4);
    expect(a.stars, 1);
    expect(a.session.stats.accuracy, 100);
    expect(a.errors, 1);
  });
  testWidgets(
    'real course completes five lines, retains session across theme, retries failed save and unlocks next',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      final store = MemoryStore(), repo = LocalRepository(MemoryStore());
      final live = LocalRepository(store);
      await live.load();
      await live.transaction((d) {
        (d['prefs'] as Map).addAll(<String, dynamic>{
          'pet': false,
          'motion': false,
        });
      });
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: false,
      );
      var clock = 100000;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        TypeFreeApp(
          resources: resources,
          repository: live,
          appearance: appearance,
          clock: () => clock,
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      expect(find.byType(CoursePage), findsOneWidget);
      final course = tester.state<CoursePageState>(find.byType(CoursePage));
      expect(course.lessons.length, 19);
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is OutlinedButton && w.onPressed != null,
            )
            .first,
      );
      await tester.pump();
      final attempt = course.attempt!;
      await tester.tap(find.byKey(const ValueKey('course-input')));
      for (var line = 0; line < attempt.lines.length; line++) {
        var prefix = '';
        final text = attempt.lines[line];
        for (var i = 0; i < text.length; i++) {
          clock += 120;
          prefix += text[i];
          if (line == attempt.lines.length - 1 && i == text.length - 1) {
            store.fail = true;
          }
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: prefix,
              selection: TextSelection.collapsed(offset: prefix.length),
            ),
          );
          await tester.pump(const Duration(milliseconds: 1));
          if (line == 0 && i == 2) {
            appearance.preview('classic-blue', ThemeMode.dark);
            await appearance.apply();
            await tester.pump();
            expect(course.attempt, same(attempt));
            expect(attempt.session.pos, 3);
          }
        }
      }
      await tester.pump();
      expect(attempt.finished, true);
      expect(course.saved, false);
      expect((live.data['legacy'] as Map).containsKey('tr_course_ru'), false);
      expect(live.data['sessions'], isEmpty);
      store.fail = false;
      await tester.tap(find.text('Повторить сохранение'));
      await tester.pump();
      expect(course.saved, true);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      await tester.pump();
      expect(
        tester.getRect(find.byType(KeyboardGuide)).bottom,
        lessThanOrEqualTo(664),
      );
      final reload = LocalRepository(store);
      await reload.load();
      expect((reload.data['sessions'] as List).length, 1);
      final progress = jsonDecode(
        (reload.data['legacy'] as Map)['tr_course_ru'] as String,
      ) as Map;
      expect(progress['stars']['1'], 3);
      expect(courseUnlocked(2, progress['stars'] as Map), true);
      await course.saveResult();
      expect((live.data['sessions'] as List).length, 1);
      expect(repo.data['sessions'], isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
}

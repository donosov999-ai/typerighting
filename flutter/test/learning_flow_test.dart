import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/learning_page.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

class DelayedLearningStore extends MemoryStore {
  Completer<void>? gate;
  Completer<void>? entered;
  @override
  Future<void> write(String key, String value) async {
    final current = gate;
    if (current != null) {
      entered?.complete();
      gate = null;
      await current.future;
    }
    await super.write(key, value);
  }
}

Future<void> typeLine(
  WidgetTester tester,
  LearningPageState page,
  void Function() advance,
) async {
  await tester.ensureVisible(find.byKey(const ValueKey('learning-input')));
  await tester.tap(find.byKey(const ValueKey('learning-input')));
  final pattern = page.engine.typing.pattern;
  var prefix = '';
  for (final ch in pattern.split('')) {
    advance();
    prefix += ch;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: prefix,
        selection: TextSelection.collapsed(offset: prefix.length),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  testWidgets('new key events survive delayed completion of an ineligible AI session', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final store = DelayedLearningStore();
    final repo = LocalRepository(store);
    await repo.transaction((doc) => (doc['prefs'] as Map).addAll(<String, dynamic>{'lang': 'en', 'pet': false, 'motion': false}));
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: false);
    final key = GlobalKey<TypeFreeAppState>();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(TypeFreeApp(key: key, initialSection: AppSection.learn, resources: resources, repository: repo, appearance: appearance));
    await tester.pump();
    final page = key.currentState!.learningKey.currentState!;
    final stats = key.currentState!.keyStatistics;
    await tester.enterText(find.byKey(const ValueKey('learning-input')), '§');
    await tester.pump();
    expect(page.engine.metrics['mastery'], 0);
    final gate = Completer<void>();
    store.gate = gate;
    store.entered = Completer<void>();
    final saving = page.finishAndSave();
    await tester.pump();
    expect(store.entered!.isCompleted, true);
    expect(stats.recorder.length, 0);
    stats.record('z', true, 100000);
    expect(stats.recorder.length, 1);
    gate.complete();
    await tester.pump();
    expect(await saving, true);
    expect(stats.recorder.length, 1);
    await stats.flush();
    final persisted = jsonDecode(repo.data['legacy']['tr_keystats']) as Map;
    expect(persisted['z']['ok'], 1);
    expect(repo.data['sessions'], isEmpty);
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('AI with no mastery does not carry abandoned errors into the next session', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.transaction((doc) => (doc['prefs'] as Map).addAll(<String, dynamic>{'lang': 'en', 'pet': false, 'motion': false}));
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: false);
    final key = GlobalKey<TypeFreeAppState>();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(TypeFreeApp(key: key, initialSection: AppSection.learn, resources: resources, repository: repo, appearance: appearance));
    await tester.pump();
    final page = key.currentState!.learningKey.currentState!;
    final stats = key.currentState!.keyStatistics;
    await tester.enterText(find.byKey(const ValueKey('learning-input')), '§');
    await tester.pump();
    expect(page.engine.metrics['mastery'], 0);
    expect(stats.recorder.length, 1);
    expect(await page.finishAndSave(), true);
    await tester.pump();
    expect(stats.recorder.length, 0);
    expect(repo.data['legacy']['tr_keystats'], isNotNull);
    expect(repo.data['sessions'], isEmpty);
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'AI route runs actual lines, preserves theme state, saves once and blocks failed exit',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          store = MemoryStore();
      final repo = LocalRepository(store);
      await repo.transaction((d) {
        (d['prefs'] as Map).addAll(<String, dynamic>{
          'lang': 'en',
          'pet': false,
          'motion': false,
        });
      });
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: false,
      );
      final key = GlobalKey<TypeFreeAppState>();
      var now = 100000;
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          initialSection: AppSection.practiceMenu,
          resources: resources,
          repository: repo,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.psychology_alt_outlined));
      await tester.pump();
      expect(find.byType(LearningPage), findsOneWidget);
      final page = key.currentState!.learningKey.currentState!,
          engine = key.currentState!.learningKey.currentState!.engine;
      await tester.tap(find.byKey(const ValueKey('learning-input')));
      var prefix = '';
      for (var i = 0; i < 3; i++) {
        now += 150;
        prefix += engine.typing.pattern[i];
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: prefix,
            selection: TextSelection.collapsed(offset: prefix.length),
          ),
        );
        await tester.pump();
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(engine.errors, 1);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: prefix.substring(0, 2),
          selection: const TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(engine.typing.pos, 3);
      expect(page.entry.text, prefix);
      final state = engine.typing;
      appearance.preview('classic-blue', ThemeMode.dark);
      await appearance.apply();
      await tester.pump();
      expect(page.engine.typing, same(state));
      expect(page.engine.typing.pos, 3);
      for (var i = 3; i < state.pattern.length; i++) {
        now += 150;
        prefix += state.pattern[i];
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: prefix,
            selection: TextSelection.collapsed(offset: prefix.length),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(page.engine.lines, 1);
      expect(page.engine.metrics['mastery'], greaterThan(0));
      await tester.ensureVisible(find.text('Left'));
      await tester.tap(find.text('Left'));
      await tester.pump();
      expect(page.engine.hand, 'left');
      expect(page.engine.lines, 0);
      final left = Set<String>.from(
        key.currentState!.keyboard.snapshot['leftHand'] as List,
      );
      for (final ch
          in page.engine.typing.pattern.split('').where((c) => c != ' ')) {
        expect(
          left.contains(key.currentState!.keyboard.hit(ch, ru: false)?['id']),
          true,
        );
      }
      await typeLine(tester, page, () => now += 150);
      expect(page.engine.lines, 1);
      store.fail = true;
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(key.currentState!.section, AppSection.learn);
      expect(page.saved, false);
      expect(page.error, isNotNull);
      store.fail = false;
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(key.currentState!.section, AppSection.practiceMenu);
      final rows = repo.data['sessions'] as List;
      expect(rows.length, 1);
      expect(rows.single['mode'], 'learn');
      await page.finishAndSave();
      expect((repo.data['sessions'] as List).length, 1);
      final reload = LocalRepository(store);
      await reload.load();
      expect((reload.data['sessions'] as List).length, 1);
      expect(
        jsonDecode(reload.data['legacy']['tr_history'] as String),
        hasLength(1),
      );
      await tester.tap(find.byIcon(Icons.psychology_alt_outlined));
      await tester.pump();
      expect(key.currentState!.learningKey.currentState!.engine.hand, 'left');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'child AI advances actual saved ladder without a speed scoreboard',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          store = MemoryStore();
      final repo = LocalRepository(store);
      await repo.transaction((d) {
        (d['prefs'] as Map).addAll(<String, dynamic>{
          'lang': 'ru',
          'profile': 'kids',
          'pet': false,
          'motion': false,
        });
        (d['legacy'] as Map)['tr_kids_ai_lvl'] = '1';
      });
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: false,
      );
      final key = GlobalKey<TypeFreeAppState>();
      var now = 100000;
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          initialSection: AppSection.learn,
          resources: resources,
          repository: repo,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      final page = key.currentState!.learningKey.currentState!;
      expect(page.engine.kidsLevel, 1);
      await typeLine(tester, page, () => now += 150);
      await typeLine(tester, page, () => now += 150);
      await tester.pump();
      expect(page.engine.kidsLevel, 2);
      expect(page.engine.kidsScore, greaterThan(0));
      expect(repo.data['legacy']['tr_kids_ai_lvl'], '2');
      expect(find.text('Мастерство'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data['legacy']['tr_kids_ai_lvl'], '2');
      expect((reload.data['sessions'] as List).single['mode'], 'learn');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'AI adult and child layouts remain usable in seven languages at 200 percent',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: false,
      );
      await tester.binding.setSurfaceSize(const Size(320, 582));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      for (final language in languages) {
        for (final profile in ['m', 'kids']) {
          final repo = LocalRepository(MemoryStore());
          await repo.transaction((d) {
            (d['prefs'] as Map).addAll(<String, dynamic>{
              'lang': language,
              'profile': profile,
              'pet': false,
              'motion': false,
            });
          });
          await tester.pumpWidget(
            TypeFreeApp(
              key: ValueKey('$language-$profile'),
              initialSection: AppSection.learn,
              resources: resources,
              repository: repo,
              appearance: appearance,
            ),
          );
          await tester.pump();
          expect(find.byKey(const ValueKey('learning-input')), findsOneWidget);
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byKey(const ValueKey('learning-input'))),
            ).scale(10),
            20,
          );
          expect(tester.takeException(), isNull, reason: '$language/$profile');
        }
      }
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

void main() {
  testWidgets(
    'heat preference, weak real exercise, retry-free save and return preserve ordinary bank',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      final store = MemoryStore(), repo = LocalRepository(MemoryStore());
      final live = LocalRepository(store);
      await live.transaction((d) {
        (d['prefs'] as Map).addAll(<String, dynamic>{
          'pet': false,
          'motion': false,
          'index': 1,
          'bank': 'ruWords',
        });
        (d['legacy'] as Map)['tr_keystats'] =
            '{"a":{"ok":6,"err":4},"f":{"ok":7,"err":3}}';
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
          initialSection: AppSection.practice,
          resources: resources,
          repository: live,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Тепловая карта'));
      await tester.pump();
      expect(
        tester.widget<KeyboardGuide>(find.byType(KeyboardGuide)).heat.keys,
        contains('a'),
      );
      final oldBank = key.currentState!.bank;
      await tester.tap(find.text('🎯 Слабые клавиши'));
      await tester.pump();
      final state = key.currentState!;
      expect(state.weakMode, true);
      expect(state.session.pattern, isNotEmpty);
      expect(state.session.pattern, contains('ф'));
      final session = state.session;
      appearance.preview('classic-blue', ThemeMode.dark);
      await appearance.apply();
      await tester.pump();
      expect(state.session, same(session));
      expect(state.weakMode, true);
      await tester.tap(find.byKey(const ValueKey('practice-input')));
      var prefix = '';
      final pattern = state.session.pattern;
      for (var i = 0; i < pattern.length; i++) {
        now += 120;
        if (pattern[i] == '\n') {
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump(const Duration(milliseconds: 1));
          continue;
        }
        prefix += pattern[i];
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: prefix,
            selection: TextSelection.collapsed(offset: prefix.length),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
      expect(
        state.session.finished,
        true,
        reason: 'position ${state.session.pos}/${state.session.pattern.length}',
      );
      expect(state.saved, true, reason: state.error);
      expect((live.data['sessions'] as List).single['mode'], 'weak');
      expect(
        (live.data['legacy'] as Map).containsKey('tr_progress_weak'),
        false,
      );
      await state.saveResult();
      expect((live.data['sessions'] as List).length, 1);
      state.exitWeak();
      await tester.pump();
      expect(state.bank, oldBank);
      expect(state.index, 1);
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data['prefs']['heat'], true);
      expect((reload.data['sessions'] as List).length, 1);
      expect(
        jsonDecode(reload.data['legacy']['tr_keystats'])['a']['ok'],
        greaterThan(6),
      );
      expect(repo.data['sessions'], isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'weak-key analysis fits seven languages at 200 percent and shows honest empty results',
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
        final repo = LocalRepository(MemoryStore());
        await repo.transaction((d) {
          (d['prefs'] as Map).addAll(<String, dynamic>{
            'lang': language,
            'pet': false,
            'motion': false,
          });
        });
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: TypeFreeApp(
              key: ValueKey(language),
              initialSection: AppSection.weakKeys,
              resources: resources,
              repository: repo,
              appearance: appearance,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('—'), findsNWidgets(2));
        expect(
          MediaQuery.textScalerOf(tester.element(find.text('—').first))
              .scale(10),
          20,
        );
        expect(tester.takeException(), isNull, reason: language);
      }
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    },
  );
}

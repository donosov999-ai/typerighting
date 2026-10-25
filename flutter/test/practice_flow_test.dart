import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';

import 'storage_transfer_test.dart' show MemoryStore;

import 'package:typefree_flutter_foundation/data/legacy_transfer.dart';

class AppearanceMemory implements AppearanceStore {
  @override
  Future<void> save(Map<String, Object> value) async {}
}

void main() {
  test('canonical keyboard keeps ISO Enter, five rows, OS Ё and context punctuation', () async {
    final res = await Resources.load();
    final win = KeyboardModel(
      Map<String, dynamic>.from(res.keyboards['windows']['qwerty'] as Map),
    );
    final mac = KeyboardModel(
      Map<String, dynamic>.from(res.keyboards['mac']['qwerty'] as Map),
    );
    expect(win.hit('ё', ru: true)?['id'], 'tilde');
    expect(mac.hit('ё', ru: true)?['id'], 'backslash');
    expect(win.hit('.', ru: true)?['id'], 'slash');
    expect(win.hit('.', ru: false)?['id'], 'period');
    expect(win.hit('A', ru: false)?['shift'], true);
    expect(win.bridge('f', 'а'), 'а');
    expect(win.bridge('А', 'f'), 'F');
    final keys = win.snapshot['keys'] as List;
    expect(keys.any((k) => k['id'] == 'space'), true);
    expect(keys.any((k) => k['id'] == 'd0'), true);
    expect(keys.firstWhere((k) => k['id'] == 'enter')['h'], greaterThan(60));
  });
  testWidgets(
    'actual practice survives theme switching then persists one real completion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      final store = MemoryStore(), repo = LocalRepository(MemoryStore());
      final live = LocalRepository(store);
      await live.load();
      await live.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
          'pet': false,
          'motion': false,
        });
      });
      final res = (await tester.runAsync(Resources.load))!;
      final appearance = AppearanceController(
        res.registry,
        AppearanceMemory(),
        existingInstall: false,
      );
      var now = 100000;
      final key = GlobalKey<TypeFreeAppState>();
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          resources: res,
          repository: live,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      final state = key.currentState!, id = state.sessionId;
      var prefix = '';
      Future<void> type(String ch) async {
        now += 150;
        prefix += ch;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: prefix,
            selection: TextSelection.collapsed(offset: prefix.length),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      await tester.tap(find.byKey(const ValueKey('practice-input')));
      await type('д');
      await type('о');
      await type('м');
      expect(state.session.pos, 3);
      final started = state.session.startedAt;
      appearance.preview('classic-blue', ThemeMode.dark);
      await appearance.apply();
      await tester.pump();
      expect(key.currentState, same(state));
      expect(state.session.pos, 3);
      expect(state.session.startedAt, started);
      expect(state.sessionId, id);
      final text = state.session.pattern;
      for (var i = 3; i < text.length; i++) {
        await type(text[i]);
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.session.finished, true);
      expect(state.saved, true);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      await tester.pump();
      final completionButton = tester.getRect(
        find.widgetWithText(FilledButton, state.tr('done.next')),
      );
      expect(completionButton.bottom, lessThan(664));
      expect(tester.takeException(), isNull);
      expect((live.data['sessions'] as List).length, 1);
      await state.saveResult();
      expect((live.data['sessions'] as List).length, 1);
      final reload = LocalRepository(store);
      await reload.load();
      final old = jsonDecode(
        (reload.data['legacy'] as Map)['tr_history'] as String,
      ) as List;
      expect(old.length, 1);
      expect(old.first['acc'], 100);
      expect(repo.data['sessions'], isEmpty);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets('desktop keyboard fits and narrow controls remain reachable', (
    tester,
  ) async {
    final res = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) {
      (d['prefs'] as Map).addAll(<String, dynamic>{
        'pet': false,
        'motion': false,
      });
    });
    final appearance = AppearanceController(
      res.registry,
      AppearanceMemory(),
      existingInstall: false,
    );
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await tester.pumpWidget(
      TypeFreeApp(resources: res, repository: repo, appearance: appearance),
    );
    await tester.pump();
    final guide = tester.getRect(find.byType(KeyboardGuide));
    expect(guide.bottom, lessThanOrEqualTo(664));
    expect(guide.width, greaterThanOrEqualTo(740));
    expect(find.text('Без пунктуации'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Без пунктуации'));
    await tester.tap(find.text('Без пунктуации'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets(
    'real practice restores allowed legacy choices and history shows provenance',
    (tester) async {
      final res = (await tester.runAsync(Resources.load))!;
      final repo = LocalRepository(MemoryStore());
      await repo.load();
      await importTransfer(
        repo,
        createTransfer({
          'tr_lang': 'ru',
          'tr_profile': 'f',
          'tr_pet': '0',
          'tr_keyb': '1',
          'typefree_practice_bank': 'ruWords',
          'tr_progress_ruWords':
              '{"bestWpm":42,"bestAcc":97,"done":["old-1"],"lastIdx":1}',
          'tr_history': '[{"t":1700000000000,"wpm":42,"acc":97}]',
          'tr_course_ru': '{"stars":{"1":3}}',
        }, exportId: 'widget-fixture'),
      );
      final appearance = AppearanceController(
        res.registry,
        AppearanceMemory(),
        existingInstall: true,
      );
      final key = GlobalKey<TypeFreeAppState>();
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          resources: res,
          repository: repo,
          appearance: appearance,
        ),
      );
      await tester.pump();
      expect(key.currentState!.profile, 'f');
      expect(key.currentState!.index, 1);
      expect(key.currentState!.language, 'ru');
      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pump();
      expect(find.text('Тренировка из прежней версии'), findsOneWidget);
      expect(find.textContaining('звёзд курса: 3'), findsOneWidget);
      expect(find.textContaining('42 WPM'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
  test(
    'paste is not a physical trainer completion shortcut; IME stays supported',
    () {
      final f = PracticeCommitFormatter();
      const old = TextEditingValue(text: '');
      expect(
        f.formatEditUpdate(
          old,
          const TextEditingValue(text: 'full pasted sentence'),
        ),
        old,
      );
      const composing = TextEditingValue(
        text: 'é',
        composing: TextRange(start: 0, end: 1),
      );
      expect(f.formatEditUpdate(old, composing), composing);
    },
  );
}

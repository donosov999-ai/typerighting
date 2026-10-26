import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/recall_page.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';
import 'package:typefree_flutter_foundation/features/practice_widgets.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

Future<void> enterRecallText(
  WidgetTester tester,
  RecallPageState page,
  void Function() advance, {
  bool wrongFirst = false,
  void Function()? beforeLast,
}) async {
  await tester.ensureVisible(find.byKey(const ValueKey('recall-input')));
  await tester.tap(find.byKey(const ValueKey('recall-input')));
  var prefix = '';
  if (wrongFirst) {
    prefix = '§';
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '§',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(const TextEditingValue());
    await tester.pump();
    expect(page.entry.text, '§');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(page.engine!.typing.errors, 1);
  }
  final text = page.engine!.typing.pattern;
  for (var i = 0; i < text.length; i++) {
    if (i == text.length - 1) beforeLast?.call();
    advance();
    prefix += text[i];
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: prefix,
        selection: TextSelection.collapsed(offset: prefix.length),
      ),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'auto hide boundary, masked hints, failed save gate, untimed keys, reload and reveal timer disposal',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          store = MemoryStore(),
          repo = LocalRepository(store);
      await repo.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
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
      var now = 100000;
      final key = GlobalKey<TypeFreeAppState>();
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
      await tester.ensureVisible(find.byIcon(Icons.extension_outlined));
      await tester.tap(find.byIcon(Icons.extension_outlined));
      await tester.pump();
      final page = key.currentState!.recallKey.currentState!;
      await tester.ensureVisible(find.byKey(const ValueKey('recall-start')));
      await tester.tap(find.byKey(const ValueKey('recall-start')));
      await tester.pump();
      final run = page.engine!, pattern = page.engine!.typing.pattern;
      final firstKey = key.currentState!.keyboard.hit(
        pattern[0],
        ru: false,
      )!['id'];
      await repo.transaction((doc) {
        (doc['legacy'] as Map)['tr_keystats'] = jsonEncode({
          firstKey: {'ok': 10, 'err': 0, 't': 250, 'bt': 150, 'nt': 10},
        });
      });
      now += 3599;
      await tester.pump(const Duration(milliseconds: 3599));
      expect(run.revealing, true);
      now++;
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(run.revealing, false);
      expect(
        tester.widget<PatternView>(find.byType(PatternView)).displayPattern,
        pattern.replaceAll(RegExp(r'[^ ]'), '·'),
      );
      expect(
        tester.widget<KeyboardGuide>(find.byType(KeyboardGuide)).expected,
        isNull,
      );
      appearance.preview('classic-blue', ThemeMode.dark);
      await appearance.apply();
      await tester.pump();
      expect(page.engine, same(run));
      expect(run.revealing, false);
      await enterRecallText(
        tester,
        page,
        () => now += 150,
        wrongFirst: true,
        beforeLast: () => store.fail = true,
      );
      expect(page.error, isNotNull);
      expect(page.saved, false);
      expect(repo.data['sessions'], isEmpty);
      now += 10000;
      await tester.pump(const Duration(seconds: 10));
      expect(page.engine, same(run));
      expect(run.result, isNotNull);
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      expect(key.currentState!.section, AppSection.recall);
      await tester.ensureVisible(find.byKey(const ValueKey('recall-auto')));
      await tester.tap(find.byKey(const ValueKey('recall-auto')));
      await tester.pump();
      expect(page.autoAdvance, false);
      store.fail = false;
      expect(await page.finishAndSave(), true);
      await tester.pump();
      expect(await page.finishAndSave(), true);
      expect(repo.data['sessions'], hasLength(1));
      expect(jsonDecode(repo.data['legacy']['tr_history']), hasLength(1));
      final point = (repo.data['sessions'] as List).single;
      final summary = tester.widget<Semantics>(
        find.byKey(ValueKey('recall-result-${page.id}')),
      );
      expect(summary.properties.label, contains('Memory record: 4'));
      expect(find.text('4 words in next set'), findsOneWidget);
      expect(
        find.text('Record means the next set size reached.'),
        findsOneWidget,
      );
      expect(summary.properties.label, contains('/ 3 ★'));
      expect(point['completedSpan'], 3);
      expect(point['nextSpan'], 4);
      expect(repo.data['legacy']['tr_span_best'], '4');
      final keys = jsonDecode(repo.data['legacy']['tr_keystats']);
      expect(keys[firstKey]['t'], 250);
      expect(keys[firstKey]['nt'], 10);
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data['sessions'], hasLength(1));
      expect(reload.data['legacy']['tr_span_best'], '4');
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      await key.currentState!.showSection(AppSection.recall);
      await tester.pump();
      final reopened = key.currentState!.recallKey.currentState!;
      await tester.ensureVisible(find.byKey(const ValueKey('recall-start')));
      await tester.tap(find.byKey(const ValueKey('recall-start')));
      await tester.pump();
      expect(reopened.engine!.roundSpan, 4);
      expect(reopened.engine!.revealing, true);
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      now += 6000;
      await tester.pump(const Duration(seconds: 6));
      expect(key.currentState!.section, AppSection.practiceMenu);
      expect(find.byType(RecallPage), findsNothing);
      expect(repo.data['sessions'], hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'manual hide, auto next3500ms, Enter/Space next, lifecycle and result timer cleanup',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          store = MemoryStore(),
          repo = LocalRepository(store);
      await repo.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
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
      var now = 100000;
      final key = GlobalKey<TypeFreeAppState>();
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          initialSection: AppSection.recall,
          resources: resources,
          repository: repo,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      final page = key.currentState!.recallKey.currentState!;
      await tester.ensureVisible(find.byKey(const ValueKey('recall-start')));
      await tester.tap(find.byKey(const ValueKey('recall-start')));
      await tester.pump();
      for (var round = 0; round < 3; round++) {
        await tester.ensureVisible(find.byKey(const ValueKey('recall-ready')));
        await tester.tap(find.byKey(const ValueKey('recall-ready')));
        await tester.pump();
        await enterRecallText(tester, page, () => now += 150);
        expect(page.saved, true);
        await tester.pump();
        final id = page.id;
        if (round == 0) {
          now += 3499;
          await tester.pump(const Duration(milliseconds: 3499));
          expect(page.id, id);
          now++;
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump();
        } else {
          await tester.sendKeyEvent(
            round == 1 ? LogicalKeyboardKey.enter : LogicalKeyboardKey.space,
          );
          await tester.pump();
        }
        expect(page.id, isNot(id));
        expect(page.engine!.revealing, true);
        expect(page.engine!.roundSpan, round + 4);
      }
      expect(repo.data['sessions'], hasLength(3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(page.engine!.revealing, false);
      final run = page.engine;
      now += 15000;
      await tester.pump(const Duration(seconds: 15));
      expect(page.engine, same(run));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await enterRecallText(tester, page, () => now += 150);
      expect(page.saved, true);
      expect(repo.data['sessions'], hasLength(4));
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      now += 5000;
      await tester.pump(const Duration(seconds: 5));
      expect(key.currentState!.section, AppSection.practiceMenu);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'valid imported decimal-form best survives new round and reload',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          store = MemoryStore(),
          repo = LocalRepository(store);
      await repo.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
          'lang': 'en',
          'pet': false,
          'motion': false,
        });
        (doc['legacy'] as Map)['tr_span_best'] = '9.0';
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
          initialSection: AppSection.recall,
          resources: resources,
          repository: repo,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      expect(key.currentState!.recallAdaptation.bestSpan, 9);
      final page = key.currentState!.recallKey.currentState!;
      await tester.ensureVisible(find.byKey(const ValueKey('recall-start')));
      await tester.tap(find.byKey(const ValueKey('recall-start')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('recall-ready')));
      await tester.tap(find.byKey(const ValueKey('recall-ready')));
      await tester.pump();
      await enterRecallText(tester, page, () => now += 150);
      expect(page.saved, true);
      expect(num.parse(repo.data['legacy']['tr_span_best']), 9);
      final reload = LocalRepository(store);
      await reload.load();
      expect(num.parse(reload.data['legacy']['tr_span_best']), 9);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    },
  );
}

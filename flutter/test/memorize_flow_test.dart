import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/memorize_page.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';
import 'package:typefree_flutter_foundation/features/practice_widgets.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

void main() {
  testWidgets(
    'five actual passes, hidden semantics/keyboard, untimed keys, failed final save and length progression',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          store = MemoryStore();
      // Use one persistent synthetic store for a genuine reload below.
      final repo = LocalRepository(store);
      await repo.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
          'lang': 'en',
          'pet': false,
          'motion': false,
        });
        (doc['legacy'] as Map)['tr_keystats'] = jsonEncode({
          'a': {'ok': 10, 'err': 0, 't': 250, 'bt': 150, 'nt': 10},
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
      await tester.ensureVisible(find.byIcon(Icons.description_outlined));
      await tester.tap(find.byIcon(Icons.description_outlined));
      await tester.pump();
      final page = key.currentState!.memorizeKey.currentState!;
      expect(find.byType(MemorizePage), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('memorize-length-$i')), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('memorize-source-classic')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('memorize-piece-0')),
      );
      await tester.tap(find.byKey(const ValueKey('memorize-piece-0')));
      await tester.pump();
      final run = page.engine!, originalText = page.engine!.text;
      for (var pass = 0; pass < 5; pass++) {
        expect(run.level, pass);
        if (pass == 4) {
          expect(
            run.displayPattern.replaceAll(' ', ''),
            matches(RegExp(r'^·+$')),
          );
          final pattern = tester.widget<PatternView>(find.byType(PatternView));
          expect(pattern.displayPattern, run.displayPattern);
          expect(pattern.displayPattern, isNot(contains(originalText)));
          expect(
            tester.widget<KeyboardGuide>(find.byType(KeyboardGuide)).expected,
            isNull,
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('memorize-input')),
        );
        await tester.tap(find.byKey(const ValueKey('memorize-input')));
        var prefix = '';
        if (pass == 0) {
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
          expect(run.typing.errors, 1);
        }
        for (var i = 0; i < originalText.length; i++) {
          if (pass == 4 && i == originalText.length - 1) store.fail = true;
          now += 150;
          prefix += originalText[i];
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: prefix,
              selection: TextSelection.collapsed(offset: prefix.length),
            ),
          );
          await tester.pump();
          if (pass == 0 && i == 2) {
            final typing = run.typing;
            appearance.preview('classic-blue', ThemeMode.dark);
            await appearance.apply();
            await tester.pump();
            expect(run.typing, same(typing));
            expect(run.typing.pos, 3);
          }
        }
        expect(run.typing.finished, true);
        if (pass < 4) {
          expect(page.saved, true);
          expect(repo.data['sessions'], hasLength(pass + 1));
          expect(await page.finishAndSave(), true);
          expect(repo.data['sessions'], hasLength(pass + 1));
          await tester.ensureVisible(
            find.byKey(const ValueKey('memorize-next')),
          );
          await tester.tap(find.byKey(const ValueKey('memorize-next')));
          await tester.pump();
        }
      }
      expect(find.byKey(const ValueKey('memorize-result-4')), findsOneWidget);
      final summary = tester.widget<Semantics>(
        find.byKey(const ValueKey('memorize-result-4')),
      );
      expect(summary.properties.label, contains('100% recall'));
      expect(page.saved, false);
      expect(page.error, isNotNull);
      expect(repo.data['sessions'], hasLength(4));
      expect(repo.data['legacy']['tr_mem_len'], isNull);
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      expect(key.currentState!.section, AppSection.memorize);
      store.fail = false;
      expect(await page.finishAndSave(), true);
      await tester.pump();
      expect(await page.finishAndSave(), true);
      expect(repo.data['sessions'], hasLength(5));
      expect(jsonDecode(repo.data['legacy']['tr_history']), hasLength(5));
      expect(repo.data['legacy']['tr_mem_len'], '1');
      final stats = jsonDecode(repo.data['legacy']['tr_keystats']);
      expect(stats['a']['t'], 250);
      expect(stats['a']['nt'], 10);
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data['sessions'], hasLength(5));
      expect(reload.data['legacy']['tr_mem_len'], '1');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    },
  );
}

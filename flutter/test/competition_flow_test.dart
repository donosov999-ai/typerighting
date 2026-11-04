import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/competition_page.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

void main() {
  testWidgets('abandoned race does not pollute the next session but keeps key data', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.transaction((doc) => (doc['prefs'] as Map).addAll(<String, dynamic>{'lang': 'en', 'pet': false, 'motion': false}));
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: false);
    final appKey = GlobalKey<TypeFreeAppState>();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(TypeFreeApp(key: appKey, initialSection: AppSection.compete, resources: resources, repository: repo, appearance: appearance));
    await tester.pump();
    final page = appKey.currentState!.competitionKey.currentState!;
    page.start('alpha_fwd');
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('competition-input')), page.engine!.typing.pattern[0]);
    await tester.pump();
    final stats = appKey.currentState!.keyStatistics;
    expect(stats.recorder.length, 1);
    expect(stats.currentStats, isNotEmpty);
    page.start('alpha_rev');
    await tester.pump();
    expect(stats.recorder.length, 0);
    expect(stats.currentStats, isNotEmpty);
    await stats.flush();
    expect(repo.data['legacy']['tr_keystats'], isNotNull);
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'actual competition route, five disciplines, blocked typing, retry and persisted replay',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          store = MemoryStore();
      final repository = LocalRepository(store);
      await repository.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
          'lang': 'en',
          'pet': false,
          'motion': false,
        });
        (doc['legacy'] as Map)['tr_compete'] = jsonEncode({
          'alpha_fwd_en': 1,
          'digits_ru': 17,
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
          repository: repository,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byIcon(Icons.emoji_events_outlined));
      await tester.tap(find.byIcon(Icons.emoji_events_outlined));
      await tester.pump();
      final page = key.currentState!.competitionKey.currentState!;
      expect(find.byType(CompetitionPage), findsOneWidget);
      for (final d in ['alpha_fwd', 'alpha_rev', 'words', 'digits', 'sprint']) {
        await tester.ensureVisible(find.byKey(ValueKey('competition-$d')));
        expect(find.byKey(ValueKey('competition-$d')), findsOneWidget);
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('competition-alpha_fwd')),
      );
      await tester.tap(find.byKey(const ValueKey('competition-alpha_fwd')));
      await tester.pump();
      final race = page.engine!;
      await tester.ensureVisible(
        find.byKey(const ValueKey('competition-input')),
      );
      await tester.tap(find.byKey(const ValueKey('competition-input')));
      var prefix = '§';
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: prefix,
          selection: TextSelection.collapsed(offset: prefix.length),
        ),
      );
      await tester.pump();
      expect(race.typing.pos, 0);
      expect(race.typing.errors, 1);
      // Backspace restores input, and never rewinds the blocked engine.
      tester.testTextInput.updateEditingValue(const TextEditingValue());
      await tester.pump();
      expect(page.entry.text, prefix);
      for (final ch in race.typing.pattern.substring(0, 3).split('')) {
        now += 150;
        prefix += ch;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: prefix,
            selection: TextSelection.collapsed(offset: prefix.length),
          ),
        );
        await tester.pump();
      }
      appearance.preview('classic-blue', ThemeMode.dark);
      await appearance.apply();
      await tester.pump();
      expect(page.engine, same(race));
      expect(race.typing.pos, 3);
      store.fail = true;
      for (final ch in race.typing.pattern.substring(3).split('')) {
        now += 150;
        prefix += ch;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: prefix,
            selection: TextSelection.collapsed(offset: prefix.length),
          ),
        );
        await tester.pump();
      }
      expect(race.result, isNotNull);
      expect(page.saved, false);
      expect(page.error, isNotNull);
      expect(repository.data['sessions'], isEmpty);
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      expect(key.currentState!.section, AppSection.compete);
      store.fail = false;
      expect(await page.finishAndSave(), true);
      await tester.pump();
      expect(await page.finishAndSave(), true);
      expect(repository.data['sessions'], hasLength(1));
      expect(jsonDecode(repository.data['legacy']['tr_history']), hasLength(1));
      expect(
        jsonDecode(repository.data['legacy']['tr_compete'])['alpha_fwd_en'],
        race.result!.wpm,
      );
      expect(
        jsonDecode(repository.data['legacy']['tr_compete'])['digits_ru'],
        17,
      );
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data['sessions'].single['timeline'], hasLength(27));
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      await key.currentState!.showSection(AppSection.compete);
      await tester.pump();
      final reentered = key.currentState!.competitionKey.currentState!;
      await tester.ensureVisible(
        find.byKey(const ValueKey('stored-replay-alpha_fwd')),
      );
      await tester.tap(find.byKey(const ValueKey('stored-replay-alpha_fwd')));
      await tester.pump();
      expect(reentered.engine!.typing.pattern, race.typing.pattern);
      expect(reentered.ghost, hasLength(27));
      expect(reentered.engine!.typing.pos, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(); // ghost timer disposed
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    },
  );
}

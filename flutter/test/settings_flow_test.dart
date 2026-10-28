import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

class CountingAppearance implements AppearanceStore {
  final saved = <Map<String, Object>>[];
  @override
  Future<void> save(Map<String, Object> value) async => saved.add(value);
}

/// Settings port of the source settings modal (src/main.ts) into the F3/F4
/// pages: imported legacy keys, hidden pattern, metronome scope, template
/// preview semantics and persistence.
void main() {
  testWidgets('legacy settings import, hidden pattern, metronome scope, template preview', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) {
      (d['prefs'] as Map)['pet'] = false;
      final legacy = d['legacy'] as Map;
      legacy['tr_sound'] = '0';
      legacy['tr_metro'] = '1';
      legacy['tr_metro_bpm'] = '150';
      legacy['tr_target_wpm'] = '55';
    });
    final store = CountingAppearance();
    final appearance = AppearanceController(resources.registry, store, existingInstall: true);
    final key = GlobalKey<TypeFreeAppState>();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance));
    await tester.pump();
    final app = key.currentState!;

    // Values the old app saved under tr_* survive the move to Flutter.
    expect(app.soundOn, false);
    expect(app.metroOn, true);
    expect(app.metroBpm, 150);
    expect(app.targetWpm, 55);
    expect(appSound.enabled(), false, reason: 'Sound setting off → no effects');

    // Metronome ticks only inside ordinary practice (source syncMetronome).
    await app.showSection(AppSection.more);
    await tester.pump();
    await tester.pump();
    expect(appSound.metronomeRunning, false);
    await app.showSection(AppSection.practice);
    await tester.pump();
    await tester.pump();
    expect(appSound.metronomeRunning, true);
    await app.showSection(AppSection.settings);
    await tester.pump();
    await tester.pump();
    expect(appSound.metronomeRunning, false);

    // F3: hide the pattern → practice shows the source hint instead of text.
    await tester.tap(find.text('Настройки ввода'));
    await tester.pump();
    final hide = find.ancestor(of: find.text('Спрятать образец'), matching: find.byType(MergeSemantics));
    await tester.tap(find.descendant(of: hide, matching: find.byType(Switch)));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(app.hidePattern, true);
    expect((repo.data['prefs'] as Map)['hide'], true);
    await app.showSection(AppSection.practice);
    await tester.pump();
    expect(find.text('образец скрыт — печатай по памяти'), findsOneWidget);
    await app.showSection(AppSection.settingsSound);
    await tester.pump();
    await tester.pump();

    // F4/M4: preview changes the look but is not saved; Cancel restores.
    final before = appearance.selection.templateId;
    final other = resources.registry.templates.keys.firstWhere((id) => id != before);
    await tester.tap(find.text(resources.registry.templates[other]!.title));
    await tester.pump();
    expect(appearance.previewing, true);
    expect(store.saved, isEmpty);
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    expect(appearance.selection.templateId, before);
    expect(store.saved, isEmpty);
    await tester.tap(find.text(resources.registry.templates[other]!.title));
    await tester.pump();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(store.saved.single['templateId'], other);

    // Text size multiplies the system text scale.
    await app.changeSetting('textSize', 1.15);
    await tester.pump();
    expect((repo.data['prefs'] as Map)['textSize'], 1.15);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('A1 welcome on first run: language, profile, continue', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) => (d['prefs'] as Map)['pet'] = false);
    expect(needsWelcome(repo.data), true);
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: false);
    final key = GlobalKey<TypeFreeAppState>();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance, welcome: needsWelcome(repo.data)));
    await tester.pump();
    final app = key.currentState!;
    expect(app.section, AppSection.welcome);
    expect(find.byType(NavigationBar), findsNothing);
    final cont = find.widgetWithText(FilledButton, 'Продолжить');
    expect(tester.widget<FilledButton>(cont).onPressed, isNull, reason: 'pick a profile first');

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(app.language, 'en');
    await tester.tap(find.text('Soft'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(app.section, AppSection.today);
    expect(app.profile, 'f');
    expect((repo.data['prefs'] as Map)['profile'], 'f');
    expect(needsWelcome(repo.data), false);

    // Fits 320 px at 200 % text in every language.
    for (final lang in ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt']) {
      final r = LocalRepository(MemoryStore());
      await r.load();
      await r.transaction((d) {
        (d['prefs'] as Map)['pet'] = false;
        (d['prefs'] as Map)['lang'] = lang;
      });
      await tester.binding.setSurfaceSize(const Size(320, 582));
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(320, 582), textScaler: TextScaler.linear(2)),
        child: TypeFreeApp(resources: resources, repository: r, appearance: appearance, welcome: true),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: lang);
    }
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('A6 profile, language and theme change from «Профиль и язык»', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) => (d['prefs'] as Map)['pet'] = false);
    final store = CountingAppearance();
    final appearance = AppearanceController(resources.registry, store, existingInstall: true);
    final key = GlobalKey<TypeFreeAppState>();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance));
    await tester.pump();
    final app = key.currentState!;

    // Reachable from «Ещё» (the profile switch lived in the old settings dialog).
    await app.showSection(AppSection.more);
    await tester.pump();
    await tester.tap(find.text('Профиль и язык'));
    await tester.pump();
    expect(app.section, AppSection.profileLanguage);

    await tester.tap(find.text('Мягкий'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(app.profile, 'f');
    expect((repo.data['prefs'] as Map)['profile'], 'f');

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(app.language, 'en');
    expect((repo.data['prefs'] as Map)['lang'], 'en');
    expect(find.text('Profile and language'), findsWidgets);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(appearance.selection.brightness, ThemeMode.light);
    expect(store.saved.single['brightness'], 'light');

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('settings pages fit 320 px in seven languages at 100% and 200% text', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    await tester.binding.setSurfaceSize(const Size(320, 582));
    for (final scale in [1.0, 2.0]) {
      for (final lang in ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt']) {
        final repo = LocalRepository(MemoryStore());
        await repo.load();
        await repo.transaction((d) {
          (d['prefs'] as Map)['pet'] = false;
          (d['prefs'] as Map)['lang'] = lang;
        });
        final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: false);
        final key = GlobalKey<TypeFreeAppState>();
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(size: const Size(320, 582), textScaler: TextScaler.linear(scale)),
          child: TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance),
        ));
        await tester.pump();
        for (final sec in [AppSection.practiceMenu, AppSection.more, AppSection.settings, AppSection.settingsInput, AppSection.settingsSound, AppSection.profileLanguage, AppSection.achievements, AppSection.progress, AppSection.companion, AppSection.practice]) {
          await key.currentState!.showSection(sec);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$lang $scale $sec');
        }
        await tester.pumpWidget(const SizedBox());
        appSound.stopMetronome();
        appearance.dispose();
      }
    }
    await tester.binding.setSurfaceSize(null);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_pet/synapse_pet.dart';
import 'package:synapse_advisor/synapse_advisor.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';
import 'package:typefree_flutter_foundation/features/synapse_panel.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// M2 / DESIGN_TEMPLATE_REF §7: face tap opens the panel (side on desktop,
/// sheet on phones), Close closes it, facts are real or «нет данных», and the
/// «Слабые клавиши» action works.
void main() {
  Future<(TypeFreeAppState, AppearanceController)> start(WidgetTester tester, Size size) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) => (d['prefs'] as Map)['profile'] = 'm');
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: true);
    final key = GlobalKey<TypeFreeAppState>();
    // MediaQuery follows the view, not the surface: size the view itself.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance, initialSection: AppSection.practice, phone: false));
    await tester.pump();
    return (key.currentState!, appearance);
  }

  Future<void> stop(WidgetTester tester, AppearanceController a) async {
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    a.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('desktop: side panel beside the exercise, Close, no data', (tester) async {
    final (app, a) = await start(tester, const Size(1280, 800));
    await tester.tap(find.byTooltip('Синапс').first);
    await tester.pump();
    expect(app.synapseSide, true);
    expect(find.text('Мой прогресс'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing, reason: 'not a modal over the text');
    expect(find.byKey(const ValueKey('practice-input')), findsOneWidget);
    expect(find.text('Нет данных — начните тренировку'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump();
    expect(app.synapseSide, false);
    expect(find.text('Мой прогресс'), findsNothing);
    expect(tester.takeException(), isNull);
    await stop(tester, a);
  });

  testWidgets('desktop shell: side rail instead of the bottom bar (B1)', (tester) async {
    final (app, a) = await start(tester, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // With the rail and the 300 px pane the full keyboard still fits 720 high.
    tester.view.physicalSize = const Size(1280, 720);
    await tester.pump();
    final guide = tester.getRect(find.byType(KeyboardGuide));
    expect(guide.width, greaterThanOrEqualTo(740));
    expect(guide.bottom, lessThanOrEqualTo(720));
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Прогресс')));
    await tester.pump();
    expect(app.section, AppSection.progress);
    tester.view.physicalSize = const Size(900, 800);
    await tester.pump();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await stop(tester, a);
  });

  testWidgets('phone: sheet with Close; «Слабые клавиши» opens weak keys', (tester) async {
    final (app, a) = await start(tester, const Size(390, 844));
    await tester.tap(find.byTooltip('Синапс').first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Потренировать слабые клавиши'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(app.section, AppSection.weakKeys);
    expect(tester.takeException(), isNull);
    await stop(tester, a);
  });

  testWidgets('sheet fits 320 px at 200 % text in seven languages', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    for (final lang in ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt']) {
      final (app, a) = await start(tester, const Size(320, 582));
      await app.changeLanguage(lang);
      await tester.pump();
      unawaited(app.openAssistant());
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull, reason: lang);
      await stop(tester, a);
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('panel shows the last saved session as it is', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final theme = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: true).theme(Brightness.dark);
    final controller = SynapseController(advisor: typingAdvisor('ru'));
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SynapsePanel(
          language: 'ru',
          tr: (k) => k,
          history: const [
            {'wpm': 30, 'accuracy': 90, 'elapsedMs': 10000},
            {'wpm': 41, 'accuracy': 97.4, 'elapsedMs': 30500},
          ],
          controller: controller,
          portrait: const SizedBox(),
          animate: false,
          onWeak: () {},
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('97%'), findsOneWidget);
    expect(find.text('41 WPM'), findsOneWidget);
    expect(find.textContaining('30.5 s'), findsOneWidget);
    expect(find.text('Сохранено тренировок: 2'), findsOneWidget);
    controller.dispose();
  });
}

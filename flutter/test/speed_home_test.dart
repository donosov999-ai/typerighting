import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/exam_page.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// Speed home (midnight-speed-v1, design 29.10): default for a new install,
/// numbers only from history («—» without it), entry points open the real
/// pages, and the layout holds at the reference widths in both variants and
/// with large text.
void main() {
  Future<(GlobalKey<TypeFreeAppState>, LocalRepository)> open(
    WidgetTester tester,
    Size size, {
    ThemeMode mode = ThemeMode.dark,
    double text = 1,
    int Function()? clock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction(
      (d) => (d['prefs'] as Map).addAll(<String, dynamic>{
        'pet': false,
        'profile': 'm',
        'lang': 'ru',
      }),
    );
    final appearance = AppearanceController(
      resources.registry,
      AppearanceMemory(),
      existingInstall: false,
    );
    expect(appearance.selection.templateId, 'midnight-speed-v1');
    if (mode != ThemeMode.system) {
      appearance.preview('midnight-speed-v1', mode);
      await appearance.apply();
    }
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: TypeFreeApp(
          key: key,
          resources: resources,
          repository: repo,
          appearance: appearance,
          phone: false,
          clock: clock,
        ),
      ),
    );
    await tester.pump();
    return (key, repo);
  }

  testWidgets('empty history: honest dashes, real entry points', (
    tester,
  ) async {
    final (key, repo) = await open(tester, const Size(390, 844));
    final before = repo.data;
    expect(find.text('Начать печатать'), findsOneWidget);
    expect(find.text('Начать курс'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Пока нет занятий'), findsOneWidget);
    expect(find.textContaining('98%'), findsNothing);
    for (final m in key.currentState!.modeEntries) {
      expect(find.byKey(ValueKey('home-mode-${m.title}')), findsOneWidget);
    }
    expect(repo.data, before, reason: 'home reads, never writes');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('home-start')));
    await tester.pump();
    expect(find.byKey(const ValueKey('practice-input')), findsOneWidget);
  });

  testWidgets('speed test opens a 1-minute typing test', (tester) async {
    final (key, _) = await open(tester, const Size(390, 844));
    await tester.ensureVisible(find.byKey(const ValueKey('home-speed-test')));
    await tester.tap(find.byKey(const ValueKey('home-speed-test')));
    await tester.pump();
    await tester.pump();
    final exam = tester.state<ExamPageState>(find.byType(ExamPage));
    expect(exam.duration, 1);
    // Back home, the «Typing test» mode itself keeps the usual 10 minutes.
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    final mode = find.byKey(
      ValueKey('home-mode-${key.currentState!.modeEntries[6].title}'),
    );
    await tester.ensureVisible(mode);
    await tester.tap(mode);
    await tester.pump();
    await tester.pump();
    expect(tester.state<ExamPageState>(find.byType(ExamPage)).duration, 10);
  });

  testWidgets('phone quick actions share a row and custom text opens', (
    tester,
  ) async {
    await open(tester, const Size(390, 844));
    // Mockup: warm-up, speed test and own text in one row on a phone.
    final warm = find.byKey(const ValueKey('home-warmup'));
    final speed = find.byKey(const ValueKey('home-speed-test'));
    final custom = find.byKey(const ValueKey('home-custom-text'));
    expect(tester.getRect(warm).top, tester.getRect(custom).top);
    expect(tester.getRect(speed).top, tester.getRect(custom).top);
    expect(tester.getRect(speed).height, tester.getRect(custom).height);
    expect(tester.getRect(custom).width, greaterThanOrEqualTo(100));
    await tester.tap(custom);
    await tester.pump();
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text uses readable full-width quick actions', (
    tester,
  ) async {
    await open(tester, const Size(390, 844), text: 2);
    final speed = find.byKey(const ValueKey('home-speed-test'));
    final custom = find.byKey(const ValueKey('home-custom-text'));
    expect(tester.getRect(custom).top, greaterThan(tester.getRect(speed).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone actions fit all supported languages', (
    tester,
  ) async {
    final (key, _) = await open(tester, const Size(390, 844));
    for (final language in languages) {
      if (key.currentState!.language != language) {
        await key.currentState!.changeLanguage(language);
        await tester.pump();
      }
      final speed = find.byKey(const ValueKey('home-speed-test'));
      final custom = find.byKey(const ValueKey('home-custom-text'));
      expect(
        tester.getRect(speed).height,
        tester.getRect(custom).height,
        reason: language,
      );
      expect(tester.takeException(), isNull, reason: language);
    }
  });

  for (final size in const [
    Size(320, 640),
    Size(360, 800),
    Size(768, 1024),
    Size(1280, 720),
    Size(1440, 900),
  ]) {
    for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
      testWidgets(
        'fits ${size.width.toInt()}×${size.height.toInt()} ${mode.name}',
        (tester) async {
          await open(tester, size, mode: mode);
          expect(find.text('Начать печатать'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('large text (160 %) at 390 px', (tester) async {
    await open(tester, const Size(390, 844), text: 1.6);
    expect(find.text('Начать печатать'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'warm-up: 2 minutes from the first key, saved, no bank progress',
    (tester) async {
      var now = 1700000000000;
      final (key, repo) = await open(
        tester,
        const Size(390, 844),
        clock: () => now,
      );
      await tester.tap(find.byKey(const ValueKey('home-warmup')));
      await tester.pump();
      final app = key.currentState!;
      expect(app.warmup, isTrue);
      expect(find.textContaining('Разминка · 2 минуты · 2:00'), findsOneWidget);
      // History keeps attempts from 10 keys (source rule), type 12.
      // One key at a time: a block inserted at once counts as a paste.
      final text = app.session.pattern.substring(0, 12);
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(
          find.byKey(const ValueKey('practice-input')),
          text.substring(0, i),
        );
        await tester.pump();
      }
      expect(app.session.pos, 12);
      now += 61000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('· 0:59'), findsOneWidget);
      expect(app.session.finished, isFalse);
      now += 60000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(app.session.finished, isTrue);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      final sessions = repo.data['sessions'] as List;
      expect(sessions, hasLength(1));
      expect((sessions.single as Map)['exercise'], 'warmup');
      expect(
        (repo.data['legacy'] as Map).keys.where((k) => '$k'.contains('warmup')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

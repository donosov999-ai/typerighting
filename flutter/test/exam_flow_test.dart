import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/data/artifact_export.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/exam_page.dart';
import 'package:typefree_flutter_foundation/features/exam_certificate.dart';
import 'package:typefree_flutter_foundation/domain/exam.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

Future<void> examKey(
  WidgetTester tester,
  ExamPageState page,
  String character,
  void Function() advance,
) async {
  advance();
  final text = page.entry.text + character;
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'real seventh mode, corrections/newline, stable early result, save retry and PNG export outcomes',
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
          ),
          key = GlobalKey<TypeFreeAppState>();
      var now = 100000, exports = 0;
      final files = <Uint8List>[];
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          initialSection: AppSection.practiceMenu,
          resources: resources,
          repository: repo,
          appearance: appearance,
          clock: () => now,
          artifactExporter: (name, bytes, mime) async {
            exports++;
            files.add(bytes);
            expect(name, startsWith('TypeFree-test-'));
            expect(mime, 'image/png');
            if (exports == 1) return ArtifactExportOutcome.cancelled;
            if (exports == 2) throw StateError('simulated export failure');
            return ArtifactExportOutcome.requested;
          },
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byIcon(Icons.speed));
      await tester.tap(find.byIcon(Icons.speed));
      await tester.pump();
      final page = key.currentState!.examKey.currentState!;
      for (final duration in [1, 5, 10]) {
        expect(find.byKey(ValueKey('exam-duration-$duration')), findsOneWidget);
      }
      await tester.enterText(find.byKey(const ValueKey('exam-target')), '0');
      await tester.ensureVisible(find.byKey(const ValueKey('exam-start')));
      await tester.tap(find.byKey(const ValueKey('exam-start')));
      await tester.pump();
      expect(page.engine, isNull);
      expect(page.error, isNotNull);
      await tester.enterText(find.byKey(const ValueKey('exam-target')), '35');
      await tester.enterText(
        find.byKey(const ValueKey('exam-name')),
        'Тест TypeFree',
      );
      await tester.tap(find.byKey(const ValueKey('exam-duration-1')));
      await tester.tap(find.byKey(const ValueKey('exam-start')));
      await tester.pump();
      final run = page.engine!;
      expect(run.durationMinutes, 1);
      expect(run.pool.every((e) => e['bank'] == 'classic'), true);
      expect(
        run.pool.any(
          (e) => ['abandon', 'engRus', 'letterByLetter'].contains(e['bank']),
        ),
        false,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('exam-input')));
      await tester.tap(find.byKey(const ValueKey('exam-input')));
      await examKey(tester, page, '§', () => now += 100);
      expect(run.typing.pos, 1);
      tester.testTextInput.updateEditingValue(const TextEditingValue());
      await tester.pump();
      expect(run.typing.pos, 0);
      expect(run.typing.errors, 1);
      for (var i = 0; i < 2; i++) {
        await examKey(tester, page, run.typing.expected!, () => now += 100);
      }
      final prefix = page.entry.text;
      await examKey(tester, page, '\n', () => now += 100);
      expect(run.typing.pos, 3);
      expect(run.typing.errors, 2);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: prefix,
          selection: TextSelection.collapsed(offset: prefix.length),
        ),
      );
      await tester.pump();
      expect(run.typing.pos, 2);
      appearance.preview('classic-blue', ThemeMode.dark);
      await appearance.apply();
      await tester.pump();
      expect(page.engine, same(run));
      expect(run.typing.pos, 2);
      for (var i = 0; i < 18; i++) {
        await examKey(tester, page, run.typing.expected!, () => now += 100);
      }
      store.fail = true;
      await tester.ensureVisible(find.byKey(const ValueKey('exam-finish')));
      await tester.tap(find.byKey(const ValueKey('exam-finish')));
      await tester.pump();
      expect(run.result, isNotNull);
      expect(page.saved, false);
      expect(repo.data['sessions'], isEmpty);
      final snapshot = run.result!.toJson();
      now += 20000;
      await tester.pump(const Duration(seconds: 20));
      expect(run.metrics.toJson(), snapshot);
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      expect(key.currentState!.section, AppSection.exam);
      store.fail = false;
      await tester.ensureVisible(find.byKey(const ValueKey('exam-retry-save')));
      await tester.tap(find.byKey(const ValueKey('exam-retry-save')));
      await tester.pump();
      expect(page.saved, true);
      expect(await page.finishAndSave(), true);
      expect(repo.data['sessions'], hasLength(1));
      expect(jsonDecode(repo.data['legacy']['tr_history']), hasLength(1));
      final point = (repo.data['sessions'] as List).single;
      final summary = tester.widget<Semantics>(
        find.byKey(ValueKey('exam-result-${page.id}')),
      );
      expect(summary.properties.label, contains('keystrokes'));
      expect(summary.properties.label, contains('Duration: 1'));
      expect(point['fullDuration'], false);
      expect(point['durationMinutes'], 1);
      expect(point['elapsedMs'], snapshot['elapsedMs']);
      expect((repo.data['prefs'] as Map)['certificateName_m'], 'Тест TypeFree');
      expect((repo.data['prefs'] as Map)['certificateName_kids'], isNull);
      expect(find.byKey(const ValueKey('exam-certificate')), findsOneWidget);
      await tester.runAsync(() => page.exportCertificate());
      await tester.pump();
      expect(page.exportStatus, examCopy('en', 'cancelled'));
      await tester.runAsync(() => page.exportCertificate());
      await tester.pump();
      expect(page.exportStatus, examCopy('en', 'exportError'));
      now += 60000;
      await tester.runAsync(() => page.exportCertificate());
      await tester.pump();
      expect(page.exportStatus, examCopy('en', 'fileRequested'));
      expect(files, hasLength(3));
      expect(identical(files[0], files[2]), true);
      expect(run.metrics.toJson(), snapshot);
      expect(repo.data['sessions'], hasLength(1));
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(files.last),
            frame = await codec.getNextFrame();
        expect(frame.image.width, 1200);
        expect(frame.image.height, 850);
        frame.image.dispose();
        codec.dispose();
      });
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data['sessions'], hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '1/5/10 deadline survives background, fixes timestamp, persists once and cancels HUD',
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
          ),
          key = GlobalKey<TypeFreeAppState>();
      var now = 100000;
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          initialSection: AppSection.exam,
          resources: resources,
          repository: repo,
          appearance: appearance,
          clock: () => now,
        ),
      );
      await tester.pump();
      final page = key.currentState!.examKey.currentState!;
      for (final minutes in [1, 5, 10]) {
        await tester.ensureVisible(
          find.byKey(ValueKey('exam-duration-$minutes')),
        );
        await tester.tap(find.byKey(ValueKey('exam-duration-$minutes')));
        await tester.ensureVisible(find.byKey(const ValueKey('exam-start')));
        await tester.tap(find.byKey(const ValueKey('exam-start')));
        await tester.pump();
        final run = page.engine!;
        await tester.ensureVisible(find.byKey(const ValueKey('exam-input')));
        await tester.tap(find.byKey(const ValueKey('exam-input')));
        for (var i = 0; i < 15; i++) {
          await examKey(tester, page, run.typing.expected!, () => now += 100);
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        now = run.endAt + 2500;
        await tester.pump(const Duration(seconds: 2));
        expect(run.finished, false);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(run.result!.elapsedMs, minutes * 60000);
        expect(run.finishedAt, run.endAt);
        expect(run.endReason, 'timeout');
        expect(run.fullDuration, true);
        expect(page.saved, true);
        final count = (repo.data['sessions'] as List).length;
        await tester.pump(const Duration(seconds: 2));
        expect(repo.data['sessions'], hasLength(count));
        await tester.ensureVisible(find.byKey(const ValueKey('exam-again')));
        await tester.tap(find.byKey(const ValueKey('exam-again')));
        await tester.pump();
      }
      expect(repo.data['sessions'], hasLength(3));
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(key.currentState!.section, AppSection.practiceMenu);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      appearance.dispose();
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('local certificate names stay scoped to profile', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!,
        store = MemoryStore(),
        repo = LocalRepository(store);
    await repo.transaction((doc) {
      (doc['prefs'] as Map).addAll(<String, dynamic>{
        'lang': 'en',
        'profile': 'kids',
        'certificateName_m': 'Adult name',
        'pet': false,
        'motion': false,
      });
    });
    final appearance = AppearanceController(
          resources.registry,
          AppearanceMemory(),
          existingInstall: false,
        ),
        key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(
      TypeFreeApp(
        key: key,
        initialSection: AppSection.exam,
        resources: resources,
        repository: repo,
        appearance: appearance,
      ),
    );
    await tester.pump();
    expect(
      key.currentState!.examKey.currentState!.nameController.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    appearance.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'seven localized certificate PNGs encode without external assets',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          dict = resources.content['dict'] as Map;
      await tester.runAsync(() async {
        for (final language in languages) {
          String tr(String key) => (dict[key] as Map)[language] as String;
          final bytes = await renderExamCertificate(
            metrics: const ExamMetrics(
              typed: 120,
              errors: 3,
              gross: 25,
              net: 24,
              accuracy: 98,
              elapsedMs: 60000,
            ),
            target: 35,
            durationMinutes: 5,
            finishedAt: 1793000000000,
            name: 'Тест TypeFree — École',
            language: language,
            tr: tr,
          );
          expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
          final codec = await ui.instantiateImageCodec(bytes),
              frame = await codec.getNextFrame();
          expect(frame.image.width, 1200);
          expect(frame.image.height, 850);
          frame.image.dispose();
          codec.dispose();
        }
      });
    },
  );
  test(
    'elapsed certificate time keeps tenths and normalizes the minute boundary',
    () {
      expect(examElapsedTime(2300), '0:02.3');
      expect(examElapsedTime(59999), '1:00.0');
      expect(examElapsedTime(0), '0:00.0');
      expect(examTime(59999), '1:00');
    },
  );
}

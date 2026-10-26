import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:typefree_flutter_foundation/domain/kids.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/kids.json').readAsStringSync()) as Map;
  final asset =
      jsonDecode(File('assets/baseline/kids.json').readAsStringSync()) as Map;
  final baseline = jsonDecode(
    File('assets/baseline/keyboard.json').readAsStringSync(),
  ) as Map;
  final levels = (asset['levels'] as List)
      .map((v) => KidsLevel.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList();
  final keyboard = KeyboardModel(
    Map<String, dynamic>.from(baseline['windows']['qwerty']),
  );
  test('264 original child runs / 6534 inputs: all33 levels, error stars, physical bridge and best progress', () {
    expect(levels.length, 33);
    expect(levels.where((l) => l.language == 'ru').length, 9);
    expect(levels.where((l) => l.language == 'en').length, 24);
    expect(levels.every((l) => l.words.length == 5), isTrue);
    expect(asset['sources'], fixture['sources']);
    for (final sample in fixture['cases'] as List) {
      final initial = (sample['initial'] as Map).map(
        (id, stars) => MapEntry(int.parse(id as String), stars as int),
      );
      final engine = KidsSession(
        levels: levels,
        progress: KidsProgress(initial),
        bridge: keyboard.bridge,
      );
      expect(engine.start(sample['id'] as int), isTrue);
      for (final event in sample['events'] as List) {
        engine.press(event['key'] as String);
        expect(
          engine.snapshot(),
          event['after'],
          reason:
              'level${sample['id']} errors${sample['errors']} opposite${sample['opposite']} key${event['key']}',
        );
      }
      expect(
        levels
            .where((l) => engine.progress.unlocked(l.id))
            .map((l) => l.id)
            .toList(),
        sample['unlocked'],
      );
      final result = engine.result!;
      expect(result.characters, levels[result.levelId - 1].words.join().length);
      expect(result.errors, sample['errors']);
    }
  });
  test('unlock fence, interruption, best stars, pause every3 and final course exit', () {
    final progress = KidsProgress({1: 3, 2: 2});
    final engine = KidsSession(levels: levels, progress: progress);
    expect(engine.start(4), isFalse);
    expect(engine.start(0), isFalse);
    expect(engine.start(34), isFalse);
    expect(engine.phase, KidsPhase.map);
    expect(engine.start(1), isTrue);
    engine.press('§');
    engine.press('к');
    engine.toMap();
    expect(progress.stars, {1: 3, 2: 2});
    expect(engine.playedThisSession, 0);
    for (var round = 0; round < 3; round++) {
      expect(engine.start(round + 1), isTrue);
      for (var i = 0; i < 8; i++) {
        engine.press('§');
      }
      for (final word in levels[round].words) {
        for (final ch in word.split('')) {
          engine.press(ch);
        }
      }
      expect(engine.phase, KidsPhase.done);
      expect(engine.result!.stars, 1);
      expect(engine.restSuggested, round == 2);
    }
    expect(progress.stars, {1: 3, 2: 2, 3: 1});
    expect(engine.next(), isTrue);
    expect(engine.level!.id, 4);
    expect(engine.wordIndex, 0);
    expect(engine.errors, 0);
    final last = KidsSession(levels: levels, progress: KidsProgress({32: 1}));
    expect(last.start(33), isTrue);
    for (final word in levels.last.words) {
      for (final ch in word.split('')) {
        last.press(ch);
      }
    }
    expect(last.hasNext, isFalse);
    expect(last.next(), isFalse);
    expect(last.phase, KidsPhase.map);
    expect(last.progress.stars, {32: 1, 33: 3});
  });
  test('golden traces and shipped lesson asset are tied to current source bytes', () {
    for (final entry in (fixture['sources'] as Map).entries) {
      expect(
        sha256
            .convert(File('../src/${entry.key}').readAsBytesSync())
            .toString(),
        entry.value,
        reason:
            'Regenerate and review source comparison after ${entry.key} changes',
      );
    }
  });
  test(
    'exact90 percent threshold and worse attempts never lower imported best',
    () {
      final small = [
        KidsLevel(id: 1, language: 'en', words: ['aa', 'bb', 'cc', 'dd', 'ee']),
      ];
      for (final errors in [0, 1, 2, 30]) {
        final engine = KidsSession(
          levels: small,
          progress: KidsProgress({1: 3}),
        );
        engine.start(1);
        for (var i = 0; i < errors; i++) {
          engine.press('Enter');
        }
        for (final word in small.first.words) {
          for (final ch in word.split('')) {
            engine.press(ch);
          }
        }
        expect(
          engine.result!.stars,
          errors == 0
              ? 3
              : errors == 1
              ? 2
              : 1,
        );
        expect(engine.progress.stars[1], 3);
        final before = engine.snapshot();
        engine.press('a');
        engine.press('Backspace');
        expect(engine.snapshot(), before);
      }
      expect(() => KidsProgress({1: 4}), throwsArgumentError);
      expect(
        () => KidsSession(
          levels: [
            KidsLevel(id: 2, language: 'en', words: ['a', 'b', 'c', 'd', 'e']),
          ],
          progress: KidsProgress(),
        ),
        throwsArgumentError,
      );
    },
  );
}

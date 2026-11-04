import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/adaptive.dart';

import 'key_statistics_test.dart' show closeTree;

void main() {
  test('zero baseline is not presented as a slowdown', () {
    final letters = [
      {'id': 'a', 'ch': 'a'},
      {'id': 'b', 'ch': 'b'},
    ];
    final stats = {
      'a': {'t': 200, 'bt': 0, 'nt': 5},
      'b': {'t': 200, 'bt': 100, 'nt': 5},
    };
    expect(recoveryLetters(stats, letters), ['b']);
  });
  test('weakness follows the active physical keyboard layout', () {
    final keyboards = jsonDecode(
      File('assets/baseline/keyboard.json').readAsStringSync(),
    ) as Map;
    for (final os in ['windows', 'mac']) {
      for (final example in [
        ('qwerty', 'q', 'q'),
        ('azerty', 'q', 'a'),
        ('qwertz', 'y', 'z'),
      ]) {
        final snapshot = Map<String, dynamic>.from(keyboards[os][example.$1]);
        final stats = {
          example.$2: {'ok': 0, 'err': 5},
        };
        expect(
          weakLetters(
            stats,
            letterInventory(snapshot, 'en', activeLayout: true),
          ).first,
          example.$3,
          reason: '$os ${example.$1}',
        );
      }
      final azerty = Map<String, dynamic>.from(keyboards[os]['azerty']);
      expect(
        letterInventory(azerty, 'en', activeLayout: true).map((e) => e['ch']),
        contains('é'),
      );
    }
  });
  test('42 source cases match weak/recovery ranking, weights and exact generated drills', () {
    final fixture = jsonDecode(
      File('test/fixtures/adaptive.json').readAsStringSync(),
    ) as Map;
    final content = jsonDecode(
      File('assets/baseline/catalog.json').readAsStringSync(),
    ) as Map;
    for (final c in fixture['cases'] as List) {
      final stats = c['initial'] as Map, expected = c['result'] as Map;
      final letters = List<Map<String, String>>.from(
        (c['letters'] as List).map((v) => Map<String, String>.from(v as Map)),
      );
      expect(
        weakLetters(stats, letters),
        expected['weak'],
        reason: '${c['os']}/${c['language']}/${c['state']}',
      );
      expect(recoveryLetters(stats, letters), expected['recovery']);
      closeTree(letterWeights(stats, letters), expected['weights']);
      var seed = 1943;
      double random() {
        seed = (seed * 1664525 + 1013904223) & 0xffffffff;
        return seed / 4294967296;
      }

      expect(
        weakDrill(
          content['corpus'][c['language']] as String,
          c['language'] as String,
          stats,
          letters,
          random: random,
        ),
        expected['lines'],
        reason: 'drill ${c['os']}/${c['language']}/${c['state']}',
      );
    }
  });
  test('empty corpus terminates and sparse data never invents a weak key', () {
    final letters = [
      {'id': 'a', 'ch': 'a'},
    ];
    expect(weakLetters({}, letters), isEmpty);
    expect(weakDrill('', 'en', {}, letters), isEmpty);
    expect(
      weakLetters({
        'a': {'ok': 1, 'err': 1},
      }, letters),
      isEmpty,
    );
  });
  test(
    'weak key absent from corpus still starts focused and usable practice',
    () {
      final letters = [
        {'id': 'z', 'ch': 'z'},
      ];
      final stats = {
        'z': {'ok': 1, 'err': 5},
      };
      final lines = weakDrill(
        'the cat sat on the mat and the cat ran home',
        'en',
        stats,
        letters,
        random: () => .4,
      );
      expect(lines, isNotEmpty);
      expect(lines.first, 'z z z z z z');
      expect(lines.skip(1).any((line) => line.length > 10), isTrue);
    },
  );
  test(
    'isolated weak key remains the focus when another target forms words',
    () {
      final lines = weakDrill(
        'q cat cat cat cat',
        'en',
        {
          'q': {'ok': 0, 'err': 10},
          'a': {'ok': 5, 'err': 5},
        },
        [
          {'id': 'q', 'ch': 'q'},
          {'id': 'a', 'ch': 'a'},
        ],
        random: () => .9,
        lines: 1,
      );
      expect(lines.first, 'q q q q q q');
      expect(lines.skip(1).join(' '), contains('cat'));
    },
  );
}

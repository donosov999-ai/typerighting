import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/adaptive.dart';

import 'key_statistics_test.dart' show closeTree;

void main() {
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
}

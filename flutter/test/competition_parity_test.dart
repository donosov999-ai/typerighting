import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/competition.dart';

void main() {
  final fixtures = jsonDecode(
    File('test/fixtures/competition.json').readAsStringSync(),
  ) as Map;
  double Function() seeded() {
    var seed = 1943;
    return () {
      seed = (seed * 1664525 + 1013904223) & 0xffffffff;
      return seed / 4294967296;
    };
  }

  test(
    'all five disciplines in seven UI languages match seeded shipped content',
    () {
      for (final item in fixtures['generation'] as List) {
        expect(
          competitionContent(
            item['discipline'],
            item['language'],
            random: seeded(),
          ),
          item['pattern'],
          reason: '${item['discipline']}/${item['language']}',
        );
      }
    },
  );
  test('105 source races: blocked errors, backspace, medals, records and replay timing', () {
    for (final item in fixtures['cases'] as List) {
      var at = 0;
      final recorded = <String>[];
      final race = CompetitionSession(
        discipline: item['discipline'],
        language: item['language'],
        previousBest: item['previousBest'],
        clock: () => at,
        random: seeded(),
        record: (ch, ok, _) => recorded.add('$ch:$ok'),
      );
      for (final step in item['steps'] as List) {
        at = step['at'];
        final pos = race.typing.pos;
        race.press('Backspace');
        expect(race.typing.pos, pos);
        race.press(step['ch']);
      }
      final expected = item['expected'];
      expect(race.typing.pattern, expected['pattern']);
      expect(race.typing.pos, expected['pos']);
      expect(race.typing.errors, expected['errors']);
      expect(race.typing.marks.toList(), expected['marks']);
      expect(
        race.result?.toJson(),
        expected['result'],
        reason: '${item['discipline']}/${item['language']}',
      );
      expect(
        race.timeline.map((t) => t.toJson()).toList(),
        expected['timeline'],
      );
      final count = recorded.length;
      race.press('x'); // finishing cannot duplicate history or key evidence
      expect(recorded, hasLength(count));
    }
  });
  test('space is required but excluded from competition speed and accuracy denominator', () {
    var at = 1000;
    final race = CompetitionSession(
      discipline: 'sprint',
      language: 'en',
      clock: () => at,
      pattern: 'a b',
    );
    race.press('a');
    at += 500;
    race.press('x');
    race.press(' ');
    at += 500;
    race.press('b');
    expect(race.result!.characters, 2);
    expect(race.result!.wpm, 24);
    expect(race.result!.accuracy, 67);
    expect(race.result!.isRecord, false);
  });
  test('timeline is capped at 5000 attempts without truncating exercise or error count', () {
    var at = 1000;
    final race = CompetitionSession(
      discipline: 'sprint',
      language: 'en',
      clock: () => at,
      pattern: 'ab',
    );
    for (var i = 0; i < 5001; i++) {
      at++;
      race.press('§');
    }
    race.press('a');
    at++;
    race.press('b');
    expect(race.timeline, hasLength(5000));
    expect(race.typing.finished, true);
    expect(race.result!.errors, 5001);
    expect(race.result!.accuracy, 0);
  });
  test('medal and record boundaries preserve original thresholds', () {
    CompetitionResult finish(int elapsed, int errors, {int best = 0}) {
      var at = 100000;
      final race = CompetitionSession(
        discipline: 'sprint',
        language: 'en',
        clock: () => at,
        pattern: 'a' * 100,
        previousBest: best,
      );
      for (var i = 0; i < errors; i++) {
        race.press('§');
      }
      for (var i = 0; i < 100; i++) {
        if (i == 99) at += elapsed;
        race.press('a');
      }
      return race.result!;
    }

    expect(finish(20000, 0).medal, 'gold'); // exactly60
    expect(finish(30000, 0).medal, 'silver'); // exactly40
    expect(finish(31000, 0).medal, 'bronze');
    expect(finish(24000, 5).medal, 'silver'); //50WPM/95%
    expect(finish(25000, 5).medal, 'ribbon');
    expect(finish(20000, 11).accuracy, 90);
    expect(finish(20000, 11).isRecord, true);
    expect(finish(20000, 12).accuracy, 89);
    expect(finish(20000, 12).isRecord, false);
    expect(finish(20000, 0, best: 60).isRecord, false);
  });
}

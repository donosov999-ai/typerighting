import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/recall.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/recall.json').readAsStringSync()) as Map;
  final corpus =
      jsonDecode(
            File('assets/baseline/catalog.json').readAsStringSync(),
          )['corpus']
          as Map;
  double Function() seeded() {
    var seed = 1943;
    return () {
      seed = (seed * 1664525 + 1013904223) & 0xffffffff;
      return seed / 4294967296;
    };
  }

  test('98 source scenarios / 294 rounds: seven pools, span3–9, masks, accuracy and adaptation', () {
    for (final item in fixture['cases'] as List) {
      var at = 100000, recorded = 0;
      final state = RecallAdaptation(
        span: item['span'],
        bestSpan: item['span'],
      );
      final engine = RecallSession(
        corpus: corpus[item['language']],
        adaptation: state,
        clock: () => at,
        random: seeded(),
        record: (_, _, _) => recorded++,
      );
      expect(engine.pool, item['pool']);
      for (var round = 0; round < 3; round++) {
        final expected = item['rounds'][round];
        expect(engine.typing.pattern, expected['before']['pattern']);
        expect(engine.displayPattern, expected['before']['display']);
        final beforeReveal = recorded;
        engine.press('§');
        expect(recorded, beforeReveal);
        expect(engine.typing.pos, 0);
        expect(engine.typing.errors, 0);
        engine.hide();
        expect(engine.displayPattern, expected['hidden']['display']);
        final text = engine.typing.pattern;
        for (var i = 0; i < text.length; i++) {
          final pos = engine.typing.pos;
          engine.press('Backspace');
          engine.press('Enter');
          expect(engine.typing.pos, pos);
          if (item['errors'] == true && i % 2 == 0) {
            at += 90;
            engine.press('§');
          }
          at += 150;
          engine.press(text[i]);
          if (i == text.length ~/ 2) {
            expect(engine.displayPattern, expected['mid']['display']);
            expect(engine.typing.errors, expected['mid']['errors']);
          }
        }
        expect(engine.result!.toJson(), expected['after']['result']);
        expect(engine.displayPattern, expected['after']['display']);
        final previous = recorded;
        engine.press('x');
        expect(recorded, previous);
        if (round < 2) engine.startRound();
      }
    }
  });
  test('best is reached next challenge, large imported records survive and empty pools fail honestly', () {
    var at = 100000;
    final adaptation = RecallAdaptation(bestSpan: 99);
    final engine = RecallSession(
      corpus: 'cat dog sun bird',
      adaptation: adaptation,
      clock: () => at,
      random: seeded(),
    );
    expect(engine.revealMs, 3600);
    engine.hide();
    for (final ch in engine.typing.pattern.split('')) {
      at += 150;
      engine.press(ch);
    }
    expect(engine.result!.completedSpan, 3);
    expect(engine.result!.nextSpan, 4);
    expect(adaptation.bestSpan, 99);
    expect(
      () => RecallSession(
        corpus: 'a bb',
        adaptation: RecallAdaptation(),
        clock: () => at,
      ),
      throwsStateError,
    );
    expect(recallWordPool('CAT cat café—ёжик 123 abcdefgh'), [
      'cat',
      'café',
      'ёжик',
    ]);
  });
  test(
    'recall90 boundary, star thresholds and min/max span are source compatible',
    () {
      for (final sample in [
        (0, 100, 3, 4),
        (1, 90, 2, 4),
        (2, 82, 1, 3),
        (4, 69, 0, 3),
      ]) {
        var at = 100000;
        final state = RecallAdaptation();
        final engine = RecallSession(
          corpus: 'cat dog sun',
          adaptation: state,
          clock: () => at,
          random: seeded(),
        );
        engine.hide();
        for (var i = 0; i < sample.$1; i++) {
          at += 90;
          engine.press('§');
        }
        for (final ch in engine.typing.pattern.split('')) {
          at += 150;
          engine.press(ch);
        }
        expect(engine.result!.accuracy, sample.$2);
        expect(engine.result!.stars, sample.$3);
        expect(state.span, sample.$4);
      }
      var at = 100000;
      final state = RecallAdaptation(span: 9, bestSpan: 9);
      final engine = RecallSession(
        corpus: 'cat dog sun sky fox red hot run box cow',
        adaptation: state,
        clock: () => at,
        random: seeded(),
      );
      engine.hide();
      for (final ch in engine.typing.pattern.split('')) {
        at += 150;
        engine.press(ch);
      }
      expect(state.span, 9);
      expect(engine.result!.up, true);
    },
  );
}

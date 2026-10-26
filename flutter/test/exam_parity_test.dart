import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/exam.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/exam.json').readAsStringSync()) as Map;
  final catalog = Map<String, dynamic>.from(
    jsonDecode(
          File('assets/baseline/catalog.json').readAsStringSync(),
        )['catalog']
        as Map,
  );
  test('91 source exams /19024 events: classic pools, free errors, corrections, rollover and deadline metrics', () {
    for (final sample in fixture['cases'] as List) {
      var at = 100000;
      final available = {
        for (final e in examClassics(catalog, sample['language'])) e['id']: e,
      };
      final pool = (sample['initial']['pool'] as List)
          .map((id) => available[id]!)
          .toList();
      final run = ExamSession(
        exercises: pool,
        durationMinutes: sample['duration'],
        target: 35,
        clock: () => at,
      );
      var count = 0;
      for (final event in sample['events'] as List) {
        at = event['at'];
        run.press(event['key']);
        count++;
        for (final checkpoint in (sample['checkpoints'] as List).where(
          (c) => c['after'] == count,
        )) {
          final expected = checkpoint['snapshot'];
          expect(run.metrics.toJson(), expected['metrics']);
          expect(run.typing.pattern, expected['pattern']);
          expect(run.typing.pos, expected['pos']);
          expect(run.typing.errors, expected['errors']);
          expect(run.typing.marks.toList(), expected['marks']);
          expect(run.completedExercises, expected['completed']);
          expect(run.index, expected['index']);
        }
      }
      at = sample['finishedAt'];
      expect(run.metrics.toJson(), sample['before']['metrics']);
      expect(run.finish().toJson(), sample['final']['metrics']);
      final saved = run.result!;
      at += 900000;
      expect(run.finish(), same(saved));
      expect(run.metrics, same(saved));
    }
  });
  test('exact deadline excludes late keystrokes; early results freeze and clock reversal stays valid', () {
    var at = 100000;
    final pool = <Map<String, dynamic>>[
      {
        'id': 'test',
        'title': 'test',
        'lines': ['abc def'],
      },
    ];
    final run = ExamSession(
      exercises: pool,
      durationMinutes: 1,
      target: 35,
      clock: () => at,
    );
    run.press('a');
    at += 1000;
    run.press('x');
    run.press('Backspace');
    run.press('b');
    final before = run.metrics;
    expect(before.typed, 2);
    expect(before.errors, 1);
    run.finish();
    at += 20000;
    expect(run.metrics.toJson(), before.toJson());
    final late = ExamSession(
      exercises: pool,
      durationMinutes: 1,
      target: 35,
      clock: () => at,
    );
    at += 60000;
    late.press('a');
    expect(late.finished, true);
    expect(late.result!.typed, 0);
    expect(late.result!.elapsedMs, 60000);
    final reversed = ExamSession(
      exercises: pool,
      durationMinutes: 5,
      target: 35,
      clock: () => at,
    );
    at -= 1000;
    expect(reversed.finish().elapsedMs, 0);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/typing.dart';

void main() {
  final traces = jsonDecode(
    File('test/fixtures/typing-traces.json').readAsStringSync(),
  ) as List;
  for (final raw in traces) {
    final item = raw as Map;
    test('legacy engine parity: ${item['name']}', () {
      var now = 0;
      final st = TypingSession(
        List<String>.from(item['lines'] as List),
        clock: () => now,
      );
      final events = item['events'] as List;
      final expected = item['expected'] as List;
      for (var i = 0; i < events.length; i++) {
        final e = events[i] as Map;
        now = e['at'] as int;
        KeyResult? result;
        if (e['op'] == 'backspace') {
          st.backspace();
        } else {
          result = st.press(
            e['ch'] as String,
            blockOnError: e['block'] as bool,
          );
        }
        expect(
          {
            'pos': st.pos,
            'errors': st.errors,
            'startedAt': st.startedAt,
            'finishedAt': st.finishedAt,
            'marks': st.marks.toList(),
            'stats': st.stats.toJson(),
            'result': result?.toJson(),
          },
          expected[i],
          reason: 'event $i',
        );
      }
    });
  }
  test('plain text matches canonical corpus without altering source', () {
    final data = jsonDecode(
      File('assets/baseline/catalog.json').readAsStringSync(),
    ) as Map;
    for (final list in (data['catalog'] as Map).values) {
      for (final e in list as List) {
        final original = List<String>.from(e['lines'] as List);
        expect(
          plainPractice(original),
          e['plainLines'],
          reason: e['id'] as String,
        );
        expect(original, e['lines']);
      }
    }
    expect(plainPractice(['Привет, мир! 😀 + 2 × 3.', '...']), [
      'Привет мир 2 3',
    ]);
  });
}

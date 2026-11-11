import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/coach_projection.dart';

/// Teacher cabinet projection (coach/2): only what the chosen scopes allow,
/// nothing from before the consent, never texts or the key stream.
void main() {
  const since = 1_800_000_000_000;
  Map<String, dynamic> compete() => {
    'id': 'race-1',
    'exercise': 'alpha_fwd',
    'title': 'Секретный заголовок',
    'language': 'ru',
    'contentLanguage': 'ru',
    'profile': 'm',
    'mode': 'compete',
    'difficulty': 'ru/compete/alpha_fwd',
    't': since + 1000,
    'wpm': 61,
    'accuracy': 97,
    'errors': 2,
    'elapsedMs': 9500,
    'len': 40,
    'errKeys': {'ж': 2},
    'medal': 'silver',
    'pattern': 'абвгдежзийклмнопрстуфхцчшщъыьэюя',
    'timeline': [
      {'c': 'а', 't': 120},
    ],
  };
  const all = {'completion', 'metrics', 'errors', 'history'};

  test('no completion consent → nothing', () {
    expect(
      coachProjection(compete(), scopes: {'metrics'}, consentSince: since),
      isNull,
    );
  });

  test('sessions before the consent never leave (no backfill)', () {
    final old = compete()..['t'] = since - 1;
    expect(coachProjection(old, scopes: all, consentSince: since), isNull);
  });

  test('without history only assignments are sent', () {
    const scopes = {'completion', 'metrics'};
    expect(
      coachProjection(compete(), scopes: scopes, consentSince: since),
      isNull,
    );
    expect(
      coachProjection(
        compete(),
        scopes: scopes,
        consentSince: since,
        assignmentId: 'a-7',
        step: 2,
      ),
      containsPair('assignment_id', 'a-7'),
    );
  });

  test('completion only: what and when, no numbers', () {
    final e = coachProjection(
      compete(),
      scopes: {'completion', 'history'},
      consentSince: since,
    )!;
    // coach/2-draft.2 §5 п.11: top level as in the package CoachEvent.
    expect(e, {
      'event_id': 'race-1',
      'kind': 'typing',
      'mode': 'compete',
      'exercise_ref': 'alpha_fwd',
      'occurred_at': '2027-01-15T08:00:01.000Z',
      'metrics': {'language': 'ru'},
    });
    expect(coachAppId, 'typerighting');
  });

  test('metrics and errors are separate scopes', () {
    final m =
        coachProjection(
              compete(),
              scopes: {'completion', 'history', 'metrics'},
              consentSince: since,
            )!['metrics']
            as Map;
    expect(m['wpm'], 61);
    expect(m['accuracy'], 97);
    expect(m['elapsed_ms'], 9500);
    expect(m['medal'], 'silver');
    final x = coachProjection(
      compete(),
      scopes: {'completion', 'history', 'errors'},
      consentSince: since,
    )!;
    expect(x['errors'], {'ж': 2}); // flat symbol → count, its own object
    expect((x['metrics'] as Map).containsKey('wpm'), isFalse);
    expect(
      coachProjection(
        compete(),
        scopes: {'completion', 'history', 'metrics'},
        consentSince: since,
      )!.containsKey('errors'),
      isFalse,
    );
  });

  test('never texts, titles or the key stream — even with every scope', () {
    final e = coachProjection(compete(), scopes: all, consentSince: since)!;
    final json = jsonEncode(e);
    for (final banned in [
      'абвгдежз',
      'Секретный',
      'timeline',
      'pattern',
      'title',
      'difficulty',
      'profile',
    ]) {
      expect(json.contains(banned), isFalse, reason: banned);
    }
  });

  test('contract limits: keys ≤ 60, strings ≤ 120, payload ≤ 16 KB', () {
    final row = compete()
      ..['exercise'] = 'x' * 121
      ..['errKeys'] = {'k' * 61: 1, 'ok': 3};
    final e = coachProjection(row, scopes: all, consentSince: since)!;
    expect(e.containsKey('exercise_ref'), isFalse);
    expect(e['errors'], {'ok': 3});
    expect(utf8.encode(jsonEncode(e)).length, lessThan(16 * 1024));
  });

  test('unknown or malformed rows are not sent', () {
    for (final bad in [
      compete()..['mode'] = 'kids',
      compete()..remove('id'),
      compete()..['t'] = 'yesterday',
    ]) {
      expect(coachProjection(bad, scopes: all, consentSince: since), isNull);
    }
  });

  test('exam and recall extras travel under metrics', () {
    final exam = {
      'id': 'exam-1',
      'exercise': 'classic',
      'language': 'en',
      'mode': 'exam',
      't': since + 5,
      'wpm': 44,
      'accuracy': 95,
      'target': 35,
      'durationMinutes': 1,
      'errKeys': <String, int>{},
    };
    final m =
        coachProjection(exam, scopes: all, consentSince: since)!['metrics']
            as Map;
    expect(m['target_wpm'], 35);
    expect(m['duration_min'], 1);
    final recall = {
      'id': 'recall-1',
      'exercise': 'span',
      'language': 'ru',
      'mode': 'recall',
      't': since + 5,
      'completedSpan': 5,
      'bestSpan': 6,
      'stars': 2,
    };
    final r =
        coachProjection(recall, scopes: all, consentSince: since)!['metrics']
            as Map;
    expect([r['completed_span'], r['best_span'], r['stars']], [5, 6, 2]);
  });
}

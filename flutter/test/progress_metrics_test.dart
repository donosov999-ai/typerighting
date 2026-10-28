import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/progress_metrics.dart';

/// Parity with the shipped TypeScript (src/stats-store.ts forecast/streakDays,
/// src/achievements.ts RULES). Fixture: node tool/export_progress.mjs runs the
/// unchanged source on synthetic storage; the source hashes guard against drift.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/progress.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('fixture was exported from the current TypeScript source', () {
    final sources = fixture['sources'] as Map<String, dynamic>;
    for (final name in ['stats-store.ts', 'achievements.ts']) {
      final bytes = File('../src/$name').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), sources[name], reason: name);
    }
  });

  test('speed forecast matches every source case', () {
    final cases = fixture['forecasts'] as List;
    expect(cases, hasLength(545));
    var nonNull = 0;
    for (final c in cases) {
      final ys = (c['ys'] as List).cast<num>();
      final actual = speedForecast(ys, c['target'] as num);
      final expected = c['result'] as Map<String, dynamic>?;
      if (expected == null) {
        expect(actual, isNull, reason: '$ys → ${c['target']}');
      } else {
        nonNull++;
        expect(actual, isNotNull, reason: '$ys → ${c['target']}');
        expect(actual!.sessions, expected['sessions']);
        expect(actual.certainty, closeTo(expected['certainty'] as num, 1e-9));
        expect(actual.target, expected['target']);
      }
    }
    expect(nonNull, greaterThan(0));
  });

  test('achievement thresholds match the source rules', () {
    final cases = fixture['badges'] as List;
    expect(cases, hasLength(1008));
    for (final c in cases) {
      final s = c['input'] as Map<String, dynamic>;
      expect(
        unlockedMilestones(
          sessions: s['sessions'] as int,
          streak: s['streak'] as int,
          maxWpm: s['maxWpm'] as num,
          maxAccuracy: s['maxAcc'] as num,
          languages: s['langs'] as int,
        ),
        (c['result'] as List).cast<String>(),
        reason: '$s',
      );
    }
  });

  test('UTC day streak matches the source', () {
    final cases = fixture['streaks'] as List;
    expect(cases, hasLength(28));
    for (final c in cases) {
      final times = (c['times'] as List).cast<num>();
      expect(utcStreak(times, c['now'] as int), c['result'], reason: '$c');
    }
  });
}

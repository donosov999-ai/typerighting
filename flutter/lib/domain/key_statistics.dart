import 'dart:math' as math;

/// Physical-key evidence, matching src/stats-store.ts. Deliberately shared
/// across profiles/languages as in the shipped app; never inferred per person.
class KeyEvidence {
  KeyEvidence(this.id, this.ok, this.at, this.gap, this.timed);
  final String id;
  final bool ok, timed;
  final int at, gap;
}

class RecordedHistory {
  RecordedHistory(this.len, this.ms, this.errors, this.errorKeys);
  final int len, ms, errors;
  final Map<String, int> errorKeys;
  bool eligible(int wpm) => wpm > 0 && len >= 10;
  Map<String, dynamic> point(int wpm, num accuracy, int at) => {
    't': at,
    'wpm': wpm,
    'acc': accuracy,
    'len': len,
    'ms': ms,
    'err': errors,
    'score':
        (wpm *
                (accuracy > 1 ? accuracy / 100 : accuracy) *
                math.min(1, len / 50))
            .round(),
  };
}

/// Runtime counters follow recordKey/pushHistory, rather than text length.
/// A snapshot is captured once at completion, then retained unchanged on retry.
class KeyRecorder {
  int lastAt = 0, length = 0, errors = 0, startAt = 0;
  Map<String, int> errorKeys = {};
  KeyEvidence record(String id, bool ok, int at, {bool timed = true}) {
    final gap = at - lastAt;
    if (lastAt > 0 && gap > 300000) _clear();
    lastAt = at;
    length++;
    if (startAt == 0) startAt = at;
    if (!ok) {
      errors++;
      errorKeys[id] = (errorKeys[id] ?? 0) + 1;
    }
    return KeyEvidence(id, ok, at, gap, timed);
  }

  /// End an abandoned exercise without discarding the per-key evidence.
  void discardSession() {
    _clear();
    lastAt = 0;
  }

  RecordedHistory take(int now) {
    final result = RecordedHistory(
      length,
      startAt != 0 && now - startAt < 3600000 ? now - startAt : 0,
      errors,
      Map.unmodifiable(errorKeys),
    );
    _clear();
    return result;
  }

  void _clear() {
    length = 0;
    errors = 0;
    startAt = 0;
    errorKeys = {};
  }
}

void applyKeyEvidence(Map<String, dynamic> stats, KeyEvidence event) {
  final s = Map<String, dynamic>.from(
    (stats[event.id] as Map?) ?? {'ok': 0, 'err': 0},
  );
  // Some historical imports contain partial key records. Treat absent counts
  // as zero; the frozen archive remains unchanged.
  s['ok'] ??= 0;
  s['err'] ??= 0;
  if (s['ts'] is num) {
    final days = (event.at - (s['ts'] as num)) / 86400000;
    if (days > .5) {
      final decay = math.pow(.5, days / 21);
      s['ok'] = (s['ok'] as num) * decay;
      s['err'] = (s['err'] as num) * decay;
      if ((s['nt'] as num?) != null && s['nt'] != 0) {
        s['nt'] = (s['nt'] as num) * decay;
      }
    }
  }
  s['ts'] = event.at;
  if (event.ok) {
    s['ok'] = (s['ok'] as num) + 1;
    if (event.timed && event.gap >= 40 && event.gap <= 12000) {
      final time = s['t'] == null
          ? event.gap.toDouble()
          : .1 * event.gap + .9 * (s['t'] as num);
      s['t'] = time;
      s['nt'] = ((s['nt'] as num?) ?? 0) + 1;
      s['bt'] = s['bt'] == null ? time : math.min(s['bt'] as num, time);
    }
  } else {
    s['err'] = (s['err'] as num) + 1;
  }
  stats[event.id] = s;
}

Map<String, double> keyHeatMap(
  Map<String, dynamic> stats, {
  int minSamples = 6,
}) => {
  for (final e in stats.entries)
    if ((((e.value as Map)['ok'] as num?) ?? 0) +
            (((e.value as Map)['err'] as num?) ?? 0) >=
        minSamples)
      e.key:
          (((e.value as Map)['err'] as num?) ?? 0) /
          ((((e.value as Map)['ok'] as num?) ?? 0) +
              (((e.value as Map)['err'] as num?) ?? 0)),
};

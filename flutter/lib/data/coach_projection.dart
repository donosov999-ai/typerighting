/// Teacher cabinet (epic 892cd2c3, contract ecosystem.coach/2): one finished
/// session → the `result_event` TypeFree sends, limited by the scopes the
/// student chose for this app. Pure: no I/O, no texts.
///
/// Never sent: typed text and exercise text, titles, own/custom texts, the key
/// stream (`timeline`, `pattern`), settings, achievements, the old version's
/// archive, and sessions from before the consent (no backfill).
/// Spec: ~/Downloads/Code claude/typerighting/TEACHER_CABINET_TYPEFREE_20261111.md
/// and ~/Documents/TeamOps/teacher-cabinet/TEACHER_CABINET_ARCHITECTURE_20261111.md.
library;

const coachAppId = 'typerighting';

/// Consent scopes (architecture §1.3). `completion` is required for a link.
const coachScopes = {'completion', 'metrics', 'errors', 'history'};

/// Modes that write history rows; the kids course keeps its stars apart.
const coachModes = {
  'practice',
  'weak',
  'course',
  'learn',
  'compete',
  'memorize',
  'recall',
  'exam',
};

/// The event for [row], or null when it must not leave the device: no
/// `completion` consent, a session from before [consentSince] (ms), a session
/// outside an assignment without `history`, an unknown mode or a malformed row.
Map<String, Object?>? coachProjection(
  Map<String, dynamic> row, {
  required Set<String> scopes,
  required int consentSince,
  bool assigned = false,
}) {
  if (!scopes.contains('completion')) return null;
  final id = row['id'], t = row['t'], mode = row['mode'];
  if (id is! String || id.isEmpty || t is! num || mode is! String) return null;
  if (!coachModes.contains(mode)) return null;
  if (t < consentSince) return null;
  if (!assigned && !scopes.contains('history')) return null;

  final metrics = <String, Object?>{
    'exercise_ref': row['exercise'],
    'language': row['language'],
  };
  num? n(String key) => row[key] is num ? row[key] as num : null;
  if (scopes.contains('metrics')) {
    for (final (out, key) in const [
      ('wpm', 'wpm'),
      ('accuracy', 'accuracy'),
      ('elapsed_ms', 'elapsedMs'),
      ('typed', 'typed'),
      ('errors', 'errors'),
      // Per mode: course/recall stars, exam goal, memory span.
      ('stars', 'stars'),
      ('target_wpm', 'target'),
      ('duration_min', 'durationMinutes'),
      ('completed_span', 'completedSpan'),
      ('best_span', 'bestSpan'),
    ]) {
      final v = n(key);
      if (v != null) metrics[out] = v;
    }
    if (row['medal'] is String) metrics['medal'] = row['medal'];
  }
  if (scopes.contains('errors') && row['errKeys'] is Map) {
    metrics['error_symbols'] = {
      for (final e in (row['errKeys'] as Map).entries)
        if (e.key is String && e.value is num) e.key as String: e.value as num,
    };
  }
  return {
    'app_id': coachAppId,
    'event_id': id,
    'occurred_at': DateTime.fromMillisecondsSinceEpoch(
      t.toInt(),
      isUtc: true,
    ).toIso8601String(),
    'kind': mode,
    'metrics': metrics,
  };
}

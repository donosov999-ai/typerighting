import 'dart:typed_data';

typedef MillisecondClock = int Function();

class TypingStats {
  const TypingStats(
    this.typed,
    this.errors,
    this.elapsedMs,
    this.wpm,
    this.accuracy,
  );
  final int typed, errors, elapsedMs, wpm, accuracy;
  Map<String, int> toJson() => {
    'typed': typed,
    'errors': errors,
    'elapsedMs': elapsedMs,
    'wpm': wpm,
    'accuracy': accuracy,
  };
}

class KeyResult {
  const KeyResult(this.accepted, this.wrong, this.finished);
  final bool accepted, wrong, finished;
  Map<String, bool> toJson() => {
    'accepted': accepted,
    'wrong': wrong,
    'finished': finished,
  };
}

/// UTF-16 indexing deliberately preserves the shipped TS engine's semantics.
class TypingSession {
  TypingSession(List<String> lines, {MillisecondClock? clock})
    : pattern = lines.join('\n'),
      clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    marks = Uint8List(pattern.length);
  }
  final String pattern;
  final MillisecondClock clock;
  late final Uint8List marks;

  /// Positions where any wrong key was pressed, even if blocked and then
  /// corrected (marks keep only the last state). Used for «remembered without
  /// a mistake» summaries; does not change typing behaviour.
  final missedAt = <int>{};
  int pos = 0, errors = 0;
  int? startedAt, finishedAt;
  int attemptedKeys = 0;
  String? get expected =>
      pos < pattern.length ? pattern.substring(pos, pos + 1) : null;
  bool get finished => finishedAt != null;

  KeyResult press(String ch, {required bool blockOnError}) {
    if (finished) return const KeyResult(false, false, true);
    startedAt ??= clock();
    attemptedKeys++;
    final normalized = ch == '\r' ? '\n' : ch;
    final ok = normalized == expected;
    if (!ok) {
      errors++;
      missedAt.add(pos);
      if (blockOnError) return const KeyResult(false, true, false);
    }
    // TypedArray writes past the end in JS are ignored (empty-pattern fixture).
    if (pos < marks.length) marks[pos] = ok ? 1 : 2;
    pos++;
    final done = pos >= pattern.length;
    if (done) finishedAt = clock();
    return KeyResult(true, !ok, done);
  }

  void backspace() {
    if (finished) return;
    if (pos > 0) {
      pos--;
      if (pos < marks.length) marks[pos] = 0;
    }
  }

  TypingStats get stats {
    final now = finishedAt ?? clock();
    // Preserve legacy epoch-zero behavior, covered by a golden trace.
    final elapsed = startedAt != null && startedAt != 0 ? now - startedAt! : 0;
    var correct = 0;
    for (var i = 0; i < pos && i < marks.length; i++) {
      if (marks[i] == 1) correct++;
    }
    final total = correct + errors;
    return TypingStats(
      correct,
      errors,
      elapsed,
      elapsed > 0 ? (correct / 5 / (elapsed / 60000)).round() : 0,
      total > 0 ? (correct / total * 100).round() : 100,
    );
  }
}

List<String> plainPractice(List<String> lines) => lines
    .map(
      (s) => s
          .replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    )
    .where((s) => s.isNotEmpty)
    .toList();

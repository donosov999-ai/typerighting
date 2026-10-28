import 'dart:math';

import 'typing.dart';

class ExamMetrics {
  const ExamMetrics({
    required this.typed,
    required this.errors,
    required this.gross,
    required this.net,
    required this.accuracy,
    required this.elapsedMs,
  });
  final int typed, errors, gross, net, accuracy, elapsedMs;
  Map<String, int> toJson() => {
    'typed': typed,
    'errors': errors,
    'gross': gross,
    'net': net,
    'accuracy': accuracy,
    'elapsedMs': elapsedMs,
  };
}

/// Real localized classics. Random ordering is supplied separately from scoring.
class ExamSession {
  ExamSession({
    required List<Map<String, dynamic>> exercises,
    required this.durationMinutes,
    required this.target,
    required this.clock,
    this.record,
  }) : pool = List.unmodifiable(exercises) {
    if (![1, 5, 10].contains(durationMinutes) ||
        !target.isFinite ||
        target < 5 ||
        target > 120) {
      throw ArgumentError('Invalid test settings');
    }
    if (pool.isEmpty ||
        pool.any(
          (e) =>
              (e['lines'] as List).isEmpty ||
              (e['lines'] as List).join(' ').isEmpty,
        )) {
      throw StateError('No test exercises');
    }
    startedAt = clock();
    endAt = startedAt + durationMinutes * 60000;
    _newText();
  }
  final List<Map<String, dynamic>> pool;
  final int durationMinutes;
  final num target;
  final MillisecondClock clock;
  final void Function(String expected, bool ok, int at)? record;
  late final int startedAt, endAt;
  late TypingSession typing;
  int completedTyped = 0,
      completedErrors = 0,
      completedExercises = 0,
      index = 0;
  ExamMetrics? result;
  int? finishedAt;
  String? endReason;
  Map<String, dynamic> get exercise => pool[index];
  bool get finished => result != null;
  int get remainingMs => max(0, endAt - (finishedAt ?? clock()));
  bool get goalMet => (result ?? metrics).net >= target;
  bool get fullDuration =>
      result != null && result!.elapsedMs >= durationMinutes * 60000;
  void _newText() {
    typing = TypingSession([
      (pool[index]['lines'] as List).join(' '),
    ], clock: clock);
  }

  ExamMetrics get metrics {
    if (result != null) return result!;
    final partial = typing.stats;
    final typed = completedTyped + partial.typed,
        errors = completedErrors + partial.errors;
    final elapsed = (clock() - startedAt).clamp(0, durationMinutes * 60000);
    final minutes = max(elapsed / 60000, 1 / 600);
    return ExamMetrics(
      typed: typed,
      errors: errors,
      gross: ((typed + errors) / 5 / minutes).round(),
      net: (typed / 5 / minutes).round(),
      accuracy: typed + errors > 0
          ? (typed / (typed + errors) * 100).round()
          : 100,
      elapsedMs: elapsed,
    );
  }

  /// Called on each wrong character (source exam beep()).
  void Function()? onWrong;

  /// Returns true only on exercise rollover, not on exam completion.
  bool press(String character) {
    if (finished) return false;
    if (clock() >= endAt) {
      finish(reason: 'timeout');
      return false;
    }
    if (character == 'Backspace') {
      typing.backspace();
      return false;
    }
    if (character.length != 1 && character != 'Enter') return false;
    final expected = typing.expected ?? '',
        ch = character == 'Enter' ? '\n' : character;
    final outcome = typing.press(ch, blockOnError: false);
    if (outcome.wrong) onWrong?.call();
    if (expected.isNotEmpty && expected != ' ' && expected != '\n') {
      record?.call(expected, !outcome.wrong, clock());
    }
    if (outcome.finished) {
      final s = typing.stats;
      completedTyped += s.typed;
      completedErrors += s.errors;
      completedExercises++;
      index = (index + 1) % pool.length;
      _newText();
      return true;
    }
    return false;
  }

  ExamMetrics finish({String reason = 'manual'}) {
    if (result != null) return result!;
    final snapshot = metrics;
    final ended = clock();
    finishedAt = ended.clamp(startedAt, endAt);
    endReason = ended >= endAt ? 'timeout' : reason;
    result = snapshot;
    return snapshot;
  }
}

List<Map<String, dynamic>> examClassics(
  Map<String, dynamic> catalog,
  String language,
) => ((catalog[language] ?? catalog['en']) as List)
    .where((e) => e['bank'] == 'classic')
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

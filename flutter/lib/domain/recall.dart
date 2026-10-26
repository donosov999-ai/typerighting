import 'dart:math';

import 'typing.dart';

List<String> recallWordPool(String corpus) {
  final words = <String>{};
  for (final word in corpus.toLowerCase().split(
    RegExp(r'[^\p{L}]+', unicode: true),
  )) {
    if (word.length >= 3 && word.length <= 7) words.add(word);
  }
  return words.toList();
}

class RecallAdaptation {
  RecallAdaptation({this.span = 3, this.bestSpan = 3}) {
    if (span < 3 || span > 9 || bestSpan < 3 || !bestSpan.isFinite) {
      throw ArgumentError('Invalid recall levels');
    }
  }
  int span;
  num bestSpan;
}

class RecallResult {
  const RecallResult({
    required this.wpm,
    required this.accuracy,
    required this.elapsedMs,
    required this.errors,
    required this.characters,
    required this.completedSpan,
    required this.nextSpan,
    required this.bestSpan,
    required this.up,
  });
  final int wpm,
      accuracy,
      elapsedMs,
      errors,
      characters,
      completedSpan,
      nextSpan;
  final num bestSpan;
  final bool up;
  int get stars => accuracy == 100
      ? 3
      : accuracy >= 90
      ? 2
      : accuracy >= 70
      ? 1
      : 0;
  Map<String, dynamic> toJson() => {
    'wpm': wpm,
    'recall': accuracy,
    'span': nextSpan,
    'bestSpan': bestSpan,
    'lastUp': up,
    'stars': stars,
  };
}

/// Character accuracy is the original recall score, not a clinical memory score.
/// bestSpan records the reached next challenge, not a claim of completed words.
class RecallSession {
  RecallSession({
    required this.corpus,
    required this.adaptation,
    required this.clock,
    this.record,
    double Function()? random,
  }) : random = random ?? Random().nextDouble {
    pool = recallWordPool(corpus);
    if (pool.isEmpty) throw StateError('No eligible words in corpus');
    startRound();
  }
  final String corpus;
  final RecallAdaptation adaptation;
  final MillisecondClock clock;
  final void Function(String expected, bool ok, int at)? record;
  final double Function() random;
  late final List<String> pool;
  late TypingSession typing;
  bool revealing = true;
  int startedAt = 0;
  late int roundSpan;
  RecallResult? result;
  int get revealMs => max(2500, roundSpan * 1200);
  String get displayPattern => revealing
      ? typing.pattern
      : List.generate(
          typing.pattern.length,
          (i) => i < typing.pos || typing.pattern[i] == ' '
              ? typing.pattern[i]
              : '·',
        ).join();

  void startRound() {
    roundSpan = adaptation.span;
    final words = <String>[];
    for (
      var guard = 0;
      words.length < roundSpan && guard < roundSpan * 20;
      guard++
    ) {
      final word = pool[(random() * pool.length).floor()];
      if (!words.contains(word)) words.add(word);
    }
    typing = TypingSession([words.join(' ')], clock: clock);
    revealing = true;
    result = null;
    startedAt = 0;
  }

  void hide() {
    if (result == null) revealing = false;
  }

  KeyResult press(String character) {
    if (revealing ||
        result != null ||
        character.length != 1 ||
        character == '\n' ||
        character == '\r') {
      return KeyResult(false, false, result != null);
    }
    if (startedAt == 0) startedAt = clock();
    final expected = typing.expected ?? '';
    final outcome = typing.press(character, blockOnError: true);
    if (expected.isNotEmpty && expected != ' ') {
      record?.call(expected, !outcome.wrong, clock());
    }
    if (outcome.finished) {
      final chars = typing.pattern.replaceAll(RegExp(r'\s'), '').length,
          ms = clock() - startedAt;
      final accuracy = chars + typing.errors > 0
          ? (chars / (chars + typing.errors) * 100).round()
          : 100;
      var up = accuracy >= 90;
      if (accuracy >= 90 && adaptation.span < 9) {
        adaptation.span++;
        up = true;
        if (adaptation.span > adaptation.bestSpan) {
          adaptation.bestSpan = adaptation.span;
        }
      } else if (accuracy < 90 && adaptation.span > 3) {
        adaptation.span--;
        up = false;
      }
      result = RecallResult(
        wpm: ms > 0 ? (chars / 5 / (ms / 60000)).round() : 0,
        accuracy: accuracy,
        elapsedMs: ms,
        errors: typing.errors,
        characters: chars,
        completedSpan: typing.pattern
            .split(' ')
            .where((word) => word.isNotEmpty)
            .length,
        nextSpan: adaptation.span,
        bestSpan: adaptation.bestSpan,
        up: up,
      );
    }
    return outcome;
  }
}

import 'dart:math';

import 'typing.dart';

const competitionDisciplines = [
  'alpha_fwd',
  'alpha_rev',
  'words',
  'digits',
  'sprint',
];
const _alphabets = {
  'en': 'abcdefghijklmnopqrstuvwxyz',
  'ru': 'абвгдежзийклмнопрстуфхцчшщъыьэюя',
};
const _words = {
  'en': 'time year people way day man thing woman life child world school state family student group country problem hand part place case week company system program work',
  'ru': 'время год человек дело жизнь день рука работа слово место вопрос сторона страна мир случай ребёнок голова система вода друг земля город конец час глаз',
};
const _sprints = {
  'en': [
    'the quick brown fox jumps',
    'practice makes perfect every day',
    'never stop learning new things',
    'small steps lead to big wins',
  ],
  'ru': [
    'тише едешь дальше будешь',
    'практика путь к мастерству',
    'учись каждый день понемногу',
    'терпение и труд всё перетрут',
  ],
};

/// The shipped competition has RU and EN content; other UI languages use EN.
String competitionLanguage(String language) => language == 'ru' ? 'ru' : 'en';

String competitionContent(
  String discipline,
  String language, {
  double Function()? random,
}) {
  if (!competitionDisciplines.contains(discipline)) {
    throw ArgumentError.value(discipline, 'discipline');
  }
  final l = competitionLanguage(language), rng = random ?? Random().nextDouble;
  int pick(int length) => (rng() * length).floor();
  if (discipline == 'alpha_fwd') return _alphabets[l]!;
  if (discipline == 'alpha_rev') {
    return _alphabets[l]!.split('').reversed.join();
  }
  if (discipline == 'digits') {
    return List.generate(
      6,
      (_) => List.generate(5, (_) => '${pick(10)}').join(),
    ).join(' ');
  }
  if (discipline == 'words') {
    final words = _words[l]!.split(' ');
    return List.generate(12, (_) => words[pick(words.length)]).join(' ');
  }
  return _sprints[l]![pick(_sprints[l]!.length)];
}

class CompetitionTick {
  const CompetitionTick(this.character, this.elapsedMs);
  final String character;
  final int elapsedMs;
  Map<String, dynamic> toJson() => {'c': character, 't': elapsedMs};
}

/// A recorded wrong key does not advance a blocked competition session.
int competitionReplayPosition(
  String pattern,
  List<CompetitionTick> ticks,
  int elapsedMs,
) {
  var position = 0;
  for (final tick in ticks) {
    if (tick.elapsedMs > elapsedMs || position >= pattern.length) break;
    final character = tick.character == '\r' ? '\n' : tick.character;
    if (character == pattern.substring(position, position + 1)) position++;
  }
  return position;
}

class CompetitionResult {
  const CompetitionResult({
    required this.wpm,
    required this.accuracy,
    required this.elapsedMs,
    required this.characters,
    required this.errors,
    required this.medal,
    required this.isRecord,
  });
  final int wpm, accuracy, elapsedMs, characters, errors;
  final String medal;
  final bool isRecord;
  Map<String, dynamic> toJson() => {
    'wpm': wpm,
    'acc': accuracy,
    'ms': elapsedMs,
    'medal': medal,
    'isRecord': isRecord,
  };
}

/// Blocked input, non-whitespace WPM and accuracy intentionally differ from
/// ordinary practice. Network publication is a separate, consented operation.
class CompetitionSession {
  CompetitionSession({
    required this.discipline,
    required String language,
    required this.clock,
    this.previousBest = 0,
    this.record,
    double Function()? random,
    String? pattern,
  }) : language = competitionLanguage(language) {
    if (!competitionDisciplines.contains(discipline)) {
      throw ArgumentError.value(discipline, 'discipline');
    }
    typing = TypingSession([
      pattern ?? competitionContent(discipline, language, random: random),
    ], clock: clock);
  }
  final String discipline, language;
  final MillisecondClock clock;
  final num previousBest;
  final void Function(String expected, bool ok, int at)? record;
  late final TypingSession typing;
  int startedAt = 0;
  final timeline = <CompetitionTick>[];
  CompetitionResult? result;
  String get bestKey => '${discipline}_$language';

  KeyResult press(String character) {
    if (typing.finished) return const KeyResult(false, false, true);
    if (character == 'Backspace' ||
        character.length != 1 && character != 'Enter') {
      return const KeyResult(false, false, false);
    }
    final ch = character == 'Enter' ? '\n' : character;
    // Preserve the original epoch-zero sentinel, including its reset quirk.
    if (startedAt == 0) startedAt = clock();
    if (timeline.length < 5000) {
      timeline.add(CompetitionTick(ch, clock() - startedAt));
    }
    final expected = typing.expected ?? '';
    final outcome = typing.press(ch, blockOnError: true);
    if (expected.isNotEmpty && expected != ' ' && expected != '\n') {
      record?.call(expected, !outcome.wrong, clock());
    }
    if (outcome.finished) {
      final ms = clock() - startedAt;
      final chars = typing.pattern.replaceAll(RegExp(r'\s'), '').length;
      final wpm = ms > 0 ? (chars / 5 / (ms / 60000)).round() : 0;
      final accuracy = chars + typing.errors > 0
          ? (chars / (chars + typing.errors) * 100).round()
          : 100;
      final medal = accuracy == 100
          ? (wpm >= 60
                ? 'gold'
                : wpm >= 40
                ? 'silver'
                : 'bronze')
          : (wpm >= 50 && accuracy >= 95 ? 'silver' : 'ribbon');
      result = CompetitionResult(
        wpm: wpm,
        accuracy: accuracy,
        elapsedMs: ms,
        characters: chars,
        errors: typing.errors,
        medal: medal,
        isRecord: wpm > previousBest && accuracy >= 90,
      );
    }
    return outcome;
  }
}

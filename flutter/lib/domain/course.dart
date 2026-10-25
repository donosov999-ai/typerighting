import 'dart:math';

import 'typing.dart';

class CourseGenerator {
  CourseGenerator(this.data, this.random);
  final Map<String, dynamic> data;
  final int Function(int) random;
  List<String> drill(String pool, String accent, int count) {
    final chars = (pool.isEmpty ? 'asdf' : pool).split('');
    final bag = [...chars, ...accent.split(''), ...accent.split('')];
    return List.generate(
      count,
      (_) => List.generate(6, (_) {
        final n = 3 + random(3);
        return List.generate(n, (_) => bag[random(bag.length)]).join();
      }).join(' '),
    );
  }

  List<String> lines(String language, Map<String, dynamic> lesson) {
    final pool = lesson['pool'] as String;
    switch (lesson['kind']) {
      case 'digits':
        return List.generate(
          5,
          (_) => List.generate(6, (_) {
            var group = '';
            // The shipped TS draws the length again on each loop condition.
            for (var i = 0; i < 3 + random(2); i++) {
              group += '${random(10)}';
            }
            return group;
          }).join(' '),
        );
      case 'punct':
        const marks = [',', '.', '?', '!', ';', ':'];
        return drill(pool, '', 4)
            .map(
              (line) => line
                  .split(' ')
                  .map((w) => w + marks[random(marks.length)])
                  .join(' '),
            )
            .toList();
      case 'words':
        final words = ((data['words'] as Map)[language] as String).split(
          RegExp(r'\s+'),
        );
        return List.generate(
          5,
          (_) => List.generate(6, (_) => words[random(words.length)]).join(' '),
        );
      case 'sentences':
        return List<String>.from((data['sentences'] as Map)[language] as List);
      case 'caps':
        return drill(pool, '', 4)
            .map(
              (line) => line
                  .split(' ')
                  .map((w) => w[0].toUpperCase() + w.substring(1))
                  .join(' '),
            )
            .toList();
      default:
        return drill(pool, lesson['newKeys'] as String, 5);
    }
  }
}

int courseStars(int errors, int characters) => errors == 0
    ? 3
    : 1 - errors / max(characters, 1) >= .92
    ? 2
    : 1;
bool courseUnlocked(int id, Map stars) =>
    id == 1 || ((stars['${id - 1}'] as num?) ?? 0) > 0;

/// Source course advances per line and reports the last line's WPM/accuracy.
/// Total lesson errors/characters determine stars independently of that metric.
class CourseAttempt {
  CourseAttempt(this.lines, {required this.clock}) {
    if (lines.isEmpty || lines.any((l) => l.isEmpty)) {
      throw ArgumentError('Empty course lines');
    }
    session = TypingSession([lines.first], clock: clock);
  }
  final List<String> lines;
  final MillisecondClock clock;
  late TypingSession session;
  int line = 0, errors = 0, characters = 0, attemptedKeys = 0;
  int? startedAt, finishedAt;
  bool get finished => finishedAt != null;
  int get stars => courseStars(errors, characters);
  bool press(String ch) {
    if (finished) return false;
    startedAt ??= clock();
    attemptedKeys++;
    final result = session.press(ch, blockOnError: true);
    if (result.wrong) errors++;
    if (result.finished) {
      characters += session.pattern.length;
      if (line + 1 < lines.length) {
        line++;
        session = TypingSession([lines[line]], clock: clock);
        return true;
      }
      finishedAt = clock();
    }
    return false;
  }
}

import 'typing.dart';

const memorizeLevels = ['full', 'third', 'half', 'first', 'blind'];
const memorizeLengths = [5, 7, 10, 0];

List<String> memorizeCleanWords(List<String> lines) => lines
    .join(' ')
    .replaceAll(RegExp('[-–—]'), ' ')
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
    .split(RegExp(r'\s+'))
    .where((s) => s.isNotEmpty)
    .toList();

class MemorizeLibrary {
  MemorizeLibrary(this.catalog);
  final Map<String, dynamic> catalog;
  List<Map<String, dynamic>> entries(String source, String language) {
    final rows = (catalog[language] ?? catalog['en']) as List;
    return rows
        .where((e) => e['bank'] == (source == 'raven' ? 'poemHymn' : 'classic'))
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  String title(String source, String language) {
    final raw = entries(source, language).first['title'] as String;
    return raw.replaceFirst(RegExp(r' - \d+/\d+$'), '');
  }

  List<String> pieces(String source, String language, int lengthIndex) {
    final stanzas = entries(source, language)
        .map((e) => memorizeCleanWords(List<String>.from(e['lines'] as List)))
        .toList();
    final length = memorizeLengths[lengthIndex];
    if (length == 0) {
      return stanzas
          .where((s) => s.length >= 3)
          .map((s) => s.join(' '))
          .toList();
    }
    final words = stanzas.expand((s) => s).toList(), result = <String>[];
    for (var i = 0; i < words.length; i += length) {
      final chunk = words.skip(i).take(length).toList();
      if (chunk.length >= 3) result.add(chunk.join(' '));
    }
    return result;
  }
}

bool memorizeShowLetter(String level, int word, bool first) => switch (level) {
  'full' => true,
  'third' => word % 3 != 2,
  'half' => word % 2 == 0,
  'first' => first,
  _ => false,
};

class MemorizePass {
  const MemorizePass(
    this.wpm,
    this.accuracy,
    this.elapsedMs,
    this.characters,
    this.errors,
  );
  final int wpm, accuracy, elapsedMs, characters, errors;
  Map<String, dynamic> toJson() => {
    'wpm': wpm,
    'accuracy': accuracy,
    'elapsedMs': elapsedMs,
    'characters': characters,
    'errors': errors,
  };
}

class MemorizeSession {
  MemorizeSession({
    required this.library,
    required this.source,
    required this.language,
    required this.clock,
    this.lengthIndex = 0,
    this.pieceIndex = 0,
    this.record,
  }) {
    if (!['raven', 'classic'].contains(source)) {
      throw ArgumentError.value(source);
    }
    if (lengthIndex < 0 || lengthIndex > 3) {
      throw ArgumentError.value(lengthIndex);
    }
    startPiece(pieceIndex);
  }
  final MemorizeLibrary library;
  final String source, language;
  final MillisecondClock clock;
  final void Function(String expected, bool ok, int at)? record;
  int lengthIndex, pieceIndex, level = 0, startedAt = 0;
  late TypingSession typing;
  late String text;
  late int activeLengthIndex;
  final passResults = <MemorizePass>[];
  late List<int> wordOf;
  late List<bool> firstLetter, isAlpha;
  bool lengthIncreased = false;
  bool get finished => level == 4 && typing.finished;
  String get levelKey => memorizeLevels[level];
  MemorizePass? get result => typing.finished ? passResults.last : null;
  int get gain => passResults.isNotEmpty && passResults.first.wpm > 0
      ? (passResults.last.wpm / passResults.first.wpm * 100).round()
      : 0;
  String get medal => result == null
      ? ''
      : result!.accuracy == 100
      ? '🥇'
      : result!.accuracy >= 90
      ? '🥈'
      : result!.accuracy >= 75
      ? '🥉'
      : '🎖';
  void startPiece(int index) {
    activeLengthIndex = lengthIndex;
    final pieces = library.pieces(source, language, lengthIndex);
    if (pieces.isEmpty) throw StateError('No source excerpts');
    pieceIndex = index % pieces.length;
    text = pieces[pieceIndex];
    level = 0;
    passResults.clear();
    lengthIncreased = false;
    _beginPass();
  }

  void _beginPass() {
    typing = TypingSession([text], clock: clock);
    startedAt = 0;
    wordOf = List.filled(text.length, -1);
    firstLetter = List.filled(text.length, false);
    isAlpha = List.filled(text.length, false);
    var word = -1, inWord = false;
    for (var i = 0; i < text.length; i++) {
      final alpha = RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text[i]);
      isAlpha[i] = alpha;
      if (alpha) {
        if (!inWord) {
          word++;
          inWord = true;
          firstLetter[i] = true;
        }
        wordOf[i] = word;
      } else {
        inWord = false;
      }
    }
  }

  bool visible(int index) =>
      index < typing.pos ||
      !isAlpha[index] ||
      memorizeShowLetter(levelKey, wordOf[index], firstLetter[index]);
  String get displayPattern =>
      List.generate(text.length, (i) => visible(i) ? text[i] : '·').join();
  KeyResult press(String character) {
    if (typing.finished) return const KeyResult(false, false, true);
    if (character == 'Backspace' ||
        character.length != 1 && character != 'Enter') {
      return const KeyResult(false, false, false);
    }
    final ch = character == 'Enter' ? '\n' : character;
    if (startedAt == 0) startedAt = clock();
    final expected = typing.expected ?? '';
    final outcome = typing.press(ch, blockOnError: true);
    if (expected.isNotEmpty && expected != ' ' && expected != '\n') {
      record?.call(expected, !outcome.wrong, clock());
    }
    if (outcome.finished) {
      final elapsed = clock() - startedAt,
          chars = text.replaceAll(RegExp(r'\s'), '').length;
      final accuracy = chars + typing.errors > 0
          ? (chars / (chars + typing.errors) * 100).round()
          : 100;
      passResults.add(
        MemorizePass(
          elapsed > 0 ? (chars / 5 / (elapsed / 60000)).round() : 0,
          accuracy,
          elapsed,
          chars,
          typing.errors,
        ),
      );
      if (level == 4 && accuracy >= 85 && lengthIndex < 3) {
        lengthIndex++;
        lengthIncreased = true;
      }
    }
    return outcome;
  }

  void nextPass() {
    if (!typing.finished || level >= 4) throw StateError('No next pass');
    level++;
    _beginPass();
  }

  void nextPiece() {
    if (!finished) throw StateError('Finish all five passes first');
    startPiece(pieceIndex + 1);
  }
}

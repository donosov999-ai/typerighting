import 'typing.dart';

class KidsLevel {
  KidsLevel({
    required this.id,
    required this.language,
    required List<String> words,
  }) : words = List.unmodifiable(words) {
    if (id < 1 ||
        !['ru', 'en'].contains(language) ||
        words.length != 5 ||
        words.any((w) => w.isEmpty)) {
      throw ArgumentError('Invalid child lesson');
    }
  }
  factory KidsLevel.fromJson(Map<String, dynamic> value) => KidsLevel(
    id: value['id'] as int,
    language: value['lang'] as String,
    words: (value['words'] as List).cast<String>(),
  );
  final int id;
  final String language;
  final List<String> words;
}

enum KidsPhase { map, level, done }

/// Best stars and unlock order belong to the pupil, not a teacher or playlist.
class KidsProgress {
  KidsProgress([Map<int, int> stars = const {}]) : _stars = Map.of(stars) {
    if (_stars.entries.any((e) => e.key < 1 || e.value < 0 || e.value > 3)) {
      throw ArgumentError('Invalid child progress');
    }
  }
  final Map<int, int> _stars;
  Map<int, int> get stars => Map.unmodifiable(_stars);
  bool unlocked(int id) => id == 1 || (_stars[id - 1] ?? 0) > 0;
  void record(int id, int stars) {
    if (id < 1 || stars < 1 || stars > 3) {
      throw ArgumentError('Invalid child result');
    }
    if (stars > (_stars[id] ?? 0)) _stars[id] = stars;
  }

  Map<String, int> toJson() =>
      _stars.map((id, stars) => MapEntry('$id', stars));
}

class KidsResult {
  const KidsResult({
    required this.levelId,
    required this.errors,
    required this.characters,
    required this.stars,
  });
  final int levelId, errors, characters, stars;
}

/// Original word-by-word controller. The UI owns persistence, feedback and the
/// cancellable 3500ms next-level timer; no background work lives in the engine.
/// No WPM target is introduced into this accuracy-first child course.
class KidsActivity {
  int completed = 0;
}

class KidsSession {
  KidsSession({
    required List<KidsLevel> levels,
    required this.progress,
    MillisecondClock? clock,
    this.bridge,
    KidsActivity? activity,
  }) : activity = activity ?? KidsActivity(),
       levels = List.unmodifiable(levels),
       clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    if (levels.isEmpty ||
        levels.asMap().entries.any((e) => e.value.id != e.key + 1)) {
      throw ArgumentError('Child lesson IDs must retain source order');
    }
  }
  final List<KidsLevel> levels;
  final KidsProgress progress;
  final MillisecondClock clock;
  final String Function(String input, String expected)? bridge;
  KidsPhase phase = KidsPhase.map;
  KidsLevel? level;
  TypingSession? typing;
  KidsResult? result;
  final KidsActivity activity;
  int get playedThisSession => activity.completed;
  int wordIndex = 0, errors = 0, characters = 0;
  int _lastStars = 0;
  bool get restSuggested => playedThisSession > 0 && playedThisSession % 3 == 0;
  bool get hasNext => level != null && level!.id < levels.length;
  String? get expected => phase == KidsPhase.level ? typing?.expected : null;

  bool start(int id) {
    if (id < 1 || id > levels.length || !progress.unlocked(id)) return false;
    level = levels[id - 1];
    wordIndex = errors = characters = 0;
    result = null;
    phase = KidsPhase.level;
    typing = TypingSession([level!.words.first], clock: clock);
    return true;
  }

  void toMap() {
    phase = KidsPhase.map;
  }

  bool next() {
    if (phase != KidsPhase.done) return false;
    if (!hasNext) {
      toMap();
      return false;
    }
    return start(level!.id + 1);
  }

  KeyResult press(String key) {
    // Navigation shortcuts on the result are handled by the focused UI, so
    // buttons remain accessible and a persistence failure cannot skip a save.
    if (phase != KidsPhase.level || typing == null || key == 'Backspace') {
      return KeyResult(false, false, phase == KidsPhase.done);
    }
    final input = key == 'Enter' ? '\n' : key;
    if (input.length != 1) return const KeyResult(false, false, false);
    final expected = typing!.expected!;
    final outcome = typing!.press(
      bridge?.call(input, expected) ?? input,
      blockOnError: true,
    );
    if (outcome.wrong) errors++;
    if (outcome.finished) {
      characters += typing!.pattern.length;
      if (wordIndex + 1 < level!.words.length) {
        wordIndex++;
        typing = TypingSession([level!.words[wordIndex]], clock: clock);
      } else {
        _lastStars = errors == 0
            ? 3
            : (1 - errors / characters) >= .9
            ? 2
            : 1;
        result = KidsResult(
          levelId: level!.id,
          errors: errors,
          characters: characters,
          stars: _lastStars,
        );
        progress.record(level!.id, _lastStars);
        activity.completed++;
        phase = KidsPhase.done;
      }
    }
    return outcome;
  }

  Map<String, dynamic> snapshot() => {
    'screen': phase.name,
    'id': level?.id,
    'wordIdx': wordIndex,
    'pattern': typing?.pattern,
    'pos': typing?.pos,
    'errors': errors,
    'characters': characters,
    'stars': _lastStars,
    'played': playedThisSession,
    'progress': progress.toJson(),
    'marks': typing?.marks.toList(),
  };
}

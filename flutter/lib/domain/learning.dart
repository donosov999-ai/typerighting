import 'dart:math';

import 'adaptive.dart';
import 'key_statistics.dart';
import 'typing.dart';

const kidsLadderRu = [
  'ао',
  'лв',
  'ыд',
  'фж',
  'пр',
  'ен',
  'кт',
  'им',
  'су',
  'гб',
  'шй',
  'зч',
  'ья',
  'ю',
  'цщ',
  'хэ',
];
const kidsLadderEn = [
  'fj',
  'dk',
  'sl',
  'ag',
  'eh',
  'ir',
  'nt',
  'ou',
  'mc',
  'vb',
  'wp',
  'yx',
  'zq',
];

class LearningAdaptation {
  LearningAdaptation({this.kidsLevel = 0, this.adultDifficulty = 0});
  int kidsLevel, adultDifficulty, kidsLinesOnLevel = 0;
  String hand = 'both';
  bool kidsEasyNext = false, adultEasyNext = false;
  final errorWindow = <double>[];
}

/// Local VerseQ-style adaptation from the shipped learn.ts, not an LLM service.
class LearningSession {
  LearningSession({
    required this.corpus,
    required this.language,
    required this.profile,
    required this.keyboard,
    required this.normalization,
    required this.clock,
    required this.statistics,
    this.record,
    String? hand,
    int kidsLevel = 0,
    int adultDifficulty = 0,
    LearningAdaptation? adaptation,
    this.hardKeys = false,
    double Function()? random,
  }) : random = random ?? Random().nextDouble,
       adaptation =
           adaptation ??
           LearningAdaptation(
             kidsLevel: kidsLevel,
             adultDifficulty: adultDifficulty,
           ) {
    if (hand != null) this.adaptation.hand = hand;
    model = NgramModel(corpus, language == 'ru' ? 'ru' : 'en');
    letters = letterInventory(keyboard, language == 'ru' ? 'ru' : 'en');
    nextLine();
  }
  final String corpus, language, profile;
  final Map<String, dynamic> keyboard;
  final Map<String, String> normalization;
  final MillisecondClock clock;
  final Map<String, dynamic> Function() statistics;
  final void Function(String, bool, int)? record;
  final double Function() random;
  bool hardKeys;
  String get hand => adaptation.hand;
  set hand(String value) => adaptation.hand = value;
  final LearningAdaptation adaptation;
  int kidsScore = 0;
  int get kidsLevel => adaptation.kidsLevel;
  set kidsLevel(int value) => adaptation.kidsLevel = value;
  int get adultDifficulty => adaptation.adultDifficulty;
  set adultDifficulty(int value) => adaptation.adultDifficulty = value;
  int get kidsLinesOnLevel => adaptation.kidsLinesOnLevel;
  set kidsLinesOnLevel(int value) => adaptation.kidsLinesOnLevel = value;
  bool get kidsEasyNext => adaptation.kidsEasyNext;
  set kidsEasyNext(bool value) => adaptation.kidsEasyNext = value;
  bool get adultEasyNext => adaptation.adultEasyNext;
  set adultEasyNext(bool value) => adaptation.adultEasyNext = value;
  List<double> get errorWindow => adaptation.errorWindow;
  late final NgramModel model;
  late final List<Map<String, String>> letters;
  late TypingSession typing;
  int correct = 0,
      keys = 0,
      errors = 0,
      ms = 0,
      lines = 0,
      lineKeys = 0,
      lineErrors = 0,
      lineStart = 0,
      lastStroke = 0;
  final intervals = <int>[];
  List<String> get ladder => language == 'ru' ? kidsLadderRu : kidsLadderEn;
  int get kidsCap => ladder.length - 1;

  String cleanLine(String value) {
    if (!hardKeys && language == 'ru') {
      value = value
          .replaceAll('Ё', 'Е')
          .replaceAll('ё', 'е')
          .replaceAll(RegExp('[ъЪ]'), '');
    }
    if (keyboard['layoutName'] == 'qwerty') {
      value = value.split('').map((c) => normalization[c] ?? c).join();
    }
    return value;
  }

  String generate({bool easy = false}) {
    final stats = statistics();
    if (profile == 'kids') {
      if (kidsLevel >= kidsCap) {
        return cleanLine(
          model.generate(
            random: random,
            chars: 22,
            weights: letterWeights(stats, letters, boost: easy ? 2 : 5),
            maxWord: easy ? 4 : 6,
          ),
        );
      }
      final pool = ladder.take(min(kidsLevel, kidsCap) + 1).join().split('');
      final newest = easy ? '' : ladder[min(kidsLevel, kidsCap)];
      final heat = keyHeatMap(stats, minSamples: 3), bag = <String>[];
      for (final ch in pool) {
        var weight = newest.contains(ch) ? 4.0 : 1.0;
        final matching = letters.where((e) => e['ch'] == ch);
        final rate = matching.isEmpty ? null : heat[matching.first['id']];
        if (rate != null && rate > 0) weight *= 1 + rate * 6;
        bag.addAll(List.filled(max(1, weight.round()), ch));
      }
      final vowels = RegExp('[аоыуиеэюяaeiou]');
      final vow = bag.where(vowels.hasMatch).toList(),
          con = bag.where((c) => !vowels.hasMatch(c)).toList();
      String pick(List<String> b) => b[(random() * b.length).floor()];
      final out = <String>[];
      var guard = 0;
      while (out.join(' ').length < 20 && guard++ < 40) {
        final len = 2 + (random() * 3).floor();
        var word = '';
        for (var i = 0; i < len; i++) {
          word += vow.isNotEmpty && con.isNotEmpty
              ? (i.isOdd ? pick(vow) : pick(con))
              : pick(bag);
        }
        out.add(word);
      }
      return out.join(' ');
    }
    final chars = profile == 'f' ? 40 : 50;
    if (hand == 'both') {
      return cleanLine(
        model.generate(
          random: random,
          chars: chars,
          weights: letterWeights(
            stats,
            letters,
            boost: easy ? 3 : (4 + adultDifficulty).toDouble(),
          ),
          maxWord: easy ? 5 : min(12, 6 + adultDifficulty),
        ),
      );
    }
    final weights = letterWeights(stats, letters),
        left = Set<String>.from(keyboard['leftHand'] as List),
        bag = <String>[];
    for (final letter in letters) {
      if ((hand == 'left') != left.contains(letter['id'])) continue;
      bag.addAll(
        List.filled(
          max(1, (weights[letter['ch']] ?? 1).round()),
          letter['ch']!,
        ),
      );
    }
    if (bag.isEmpty) return '';
    final out = <String>[];
    var guard = 0;
    while (out.join(' ').length < chars && guard++ < 60) {
      final length = 3 + (random() * 6).floor();
      var word = '';
      for (var i = 0; i < length; i++) {
        word += bag[(random() * bag.length).floor()];
      }
      out.add(word);
    }
    return out.join(' ');
  }

  void nextLine() {
    final easy = profile == 'kids' ? kidsEasyNext : adultEasyNext;
    typing = TypingSession([generate(easy: easy)], clock: clock);
    kidsEasyNext = false;
    adultEasyNext = false;
    lineKeys = 0;
    lineErrors = 0;
    lineStart = 0;
    lastStroke = 0;
  }

  double? windowAverage() {
    errorWindow.add(lineKeys > 0 ? lineErrors / lineKeys : 0);
    if (errorWindow.length > 3) errorWindow.removeAt(0);
    return errorWindow.length < 2
        ? null
        : errorWindow.reduce((a, b) => a + b) / errorWindow.length;
  }

  void adapt() {
    final avg = windowAverage();
    if (profile == 'kids') {
      kidsLinesOnLevel++;
      if (avg == null || kidsLinesOnLevel < 2) return;
      if (avg < .10 && kidsLevel < kidsCap) {
        kidsLevel++;
        kidsLinesOnLevel = 0;
        errorWindow.clear();
        kidsEasyNext = false;
      } else if (avg > .25) {
        kidsEasyNext = true;
        if (avg > .35 && kidsLevel > 0) kidsLevel--;
        kidsLinesOnLevel = 0;
        errorWindow.clear();
      }
    } else {
      if (avg == null) return;
      if (avg < .06 && adultDifficulty < 6) {
        adultDifficulty++;
        errorWindow.clear();
        adultEasyNext = false;
      } else if (avg > .18) {
        adultEasyNext = true;
        if (avg > .30 && adultDifficulty > 0) adultDifficulty--;
        errorWindow.clear();
      }
    }
  }

  bool press(String ch) {
    final now = clock();
    if (typing.startedAt == null) {
      lineStart = now;
      lastStroke = now;
    }
    final expected = typing.expected ?? '';
    final r = typing.press(ch, blockOnError: true);
    if (r.accepted) {
      final dt = now - lastStroke;
      if (dt > 0 && dt < 3000) intervals.add(dt);
      lastStroke = now;
      keys++;
      if (expected != ' ' && expected != '\n') correct++;
    }
    if (expected.isNotEmpty && expected != ' ' && expected != '\n') {
      record?.call(expected, !r.wrong, now);
    }
    if (r.wrong) errors++;
    if (expected.isNotEmpty && expected != ' ' && expected != '\n') {
      lineKeys++;
      if (r.wrong) {
        lineErrors++;
        if (profile == 'kids') kidsScore = max(0, kidsScore - 5);
      } else if (profile == 'kids') {
        kidsScore += 10;
      }
    }
    if (r.finished) {
      ms += now - lineStart;
      lines++;
      if (profile == 'kids' || hand == 'both') adapt();
      nextLine();
    }
    return r.finished;
  }

  Map<String, int> get metrics {
    final minutes = ms / 60000, total = correct + errors;
    var rhythm = 0;
    if (intervals.length >= 4) {
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance =
          intervals.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
          intervals.length;
      rhythm = ((1 - sqrt(variance) / (mean == 0 ? 1 : mean)) * 100)
          .round()
          .clamp(0, 100);
    }
    return {
      'mastery': minutes > 0 ? (correct / minutes).round() : 0,
      'tempo': minutes > 0 ? ((correct + errors) / minutes).round() : 0,
      'rhythm': rhythm,
      'accuracy': total > 0 ? (correct / total * 100).round() : 100,
    };
  }

  int get mood {
    if (correct + errors == 0) return 4;
    final a = metrics['accuracy']!;
    var m = a >= 99
        ? 8
        : a >= 95
        ? 7
        : a >= 90
        ? 6
        : a >= 84
        ? 5
        : a >= 76
        ? 4
        : a >= 66
        ? 3
        : a >= 55
        ? 2
        : a >= 45
        ? 1
        : 0;
    if (kidsScore >= 300 && m < 8) m++;
    return m.clamp(0, 8);
  }

  void changeHand(String value) {
    hand = value;
    correct = 0;
    keys = 0;
    errors = 0;
    ms = 0;
    intervals.clear();
    lines = 0;
    nextLine();
  }
}

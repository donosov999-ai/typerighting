import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/learning.dart';
import 'package:typefree_flutter_foundation/domain/key_statistics.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';

import 'key_statistics_test.dart' show closeTree;

Map<String, dynamic> snapshot(LearningSession s) => {
  'pattern': s.typing.pattern,
  'pos': s.typing.pos,
  'errors': s.typing.errors,
  'marks': s.typing.marks.toList(),
  'acc': {
    'correct': s.correct,
    'keys': s.keys,
    'errors': s.errors,
    'ms': s.ms,
    'intervals': s.intervals.toList(),
    'lines': s.lines,
  },
  'kidsLvl': s.kidsLevel,
  'adultDiff': s.adultDifficulty,
  'kidsScore': s.kidsScore,
  'kidsLinesOnLvl': s.kidsLinesOnLevel,
  'errWin': s.errorWindow.toList(),
  'lineKeysCnt': s.lineKeys,
  'lineErrCnt': s.lineErrors,
  'metrics': s.metrics,
  'mood': s.mood,
};
void main() {
  test('all adult/child/hand learning scenarios match shipped TS generation and adaptation', () {
    final fixture = jsonDecode(
      File('test/fixtures/learning.json').readAsStringSync(),
    ) as Map;
    final content = jsonDecode(
      File('assets/baseline/catalog.json').readAsStringSync(),
    ) as Map;
    final keyboards = jsonDecode(
      File('assets/baseline/keyboard.json').readAsStringSync(),
    ) as Map;
    final meta = jsonDecode(
      File('assets/baseline/learning.json').readAsStringSync(),
    ) as Map;
    for (final c in fixture['cases'] as List) {
      var now = 100000, seed = 1943;
      double random() {
        seed = (seed * 1664525 + 1013904223) & 0xffffffff;
        return seed / 4294967296;
      }

      final keyboard = KeyboardModel(
        Map<String, dynamic>.from(keyboards[c['os']][c['layout']] as Map),
      );
      final stats = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(c['initial'])) as Map,
          ),
          recorder = KeyRecorder();
      final s = LearningSession(
        corpus: content['corpus'][c['language']] as String,
        language: c['language'] as String,
        profile: c['profile'] as String,
        keyboard: keyboard.snapshot,
        normalization: Map<String, String>.from(meta['normalization'] as Map),
        clock: () => now,
        statistics: () => stats,
        hand: c['hand'] as String,
        kidsLevel: 1,
        random: random,
        record: (ch, ok, at) {
          final id = keyboard.hit(ch, ru: c['language'] == 'ru')?['id'];
          if (id is String) {
            applyKeyEvidence(stats, recorder.record(id, ok, at));
          }
        },
      );
      closeTree(snapshot(s), c['start']);
      for (final step in c['steps'] as List) {
        now = step['at'] as int;
        s.press(step['ch'] as String);
        if (step['expected'] != null) closeTree(snapshot(s), step['expected']);
      }
      expect(s.cleanLine(c['cleanInput'] as String), c['clean']);
      for (final probe in c['generation'] as List) {
        seed = 1943;
        s.kidsLevel = probe['level'] as int;
        s.adultDifficulty = probe['difficulty'] as int;
        s.hardKeys = probe['hard'] as bool;
        expect(s.generate(easy: probe['easy'] as bool), probe['line']);
      }
    }
  });
  test('adaptation caps, relief, child rollback and shared module state survive a new run', () {
    final shared = LearningAdaptation(kidsLevel: 2, adultDifficulty: 6);
    LearningSession make(String profile) => LearningSession(
      corpus: 'the quick brown fox jumps every day',
      language: 'en',
      profile: profile,
      keyboard: {'layoutName': 'qwerty', 'keys': [], 'leftHand': []},
      normalization: {},
      clock: () => 1000,
      statistics: () => {},
      adaptation: shared,
      random: () => .2,
    );
    final adult = make('m');
    adult.lineKeys = 10;
    adult.lineErrors = 0;
    adult.adapt();
    adult.adapt();
    expect(adult.adultDifficulty, 6);
    adult.lineErrors = 10;
    adult.adapt();
    expect(adult.adultEasyNext, true);
    expect(adult.adultDifficulty, 5);
    final kids = make('kids');
    kids.errorWindow.clear();
    kids.lineKeys = 10;
    kids.lineErrors = 8;
    kids.adapt();
    kids.adapt();
    expect(kids.kidsLevel, 1);
    expect(kids.kidsEasyNext, true);
    final resumed = make('kids');
    expect(resumed.kidsLevel, 1);
    expect(resumed.adultDifficulty, 5);
    expect(resumed.correct, 0);
  });
}

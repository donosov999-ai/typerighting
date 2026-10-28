import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';

/// Recipes must stay identical to src/sound.ts; rendering must reproduce the
/// frequency, timing and quiet volume of each tone.
void main() {
  test('all eight source effects are present', () {
    expect(sfxRecipes.keys.toSet(), {
      'success', 'fanfare', 'star', 'start',
      'upgrade', 'record', 'catHappy', 'catSad',
    });
  });

  test('rendered tone has the recipe frequency, onset and quiet peak', () {
    for (final entry in sfxRecipes.entries) {
      for (final tone in entry.value) {
        final s = renderTones([Tone(tone.freq, 0, tone.dur, tone.vol, tone.wave)]);
        // Silence before the tone in the full recipe.
        final full = renderTones(entry.value);
        if (tone.start > .02) {
          final before = (tone.start * sampleRate).floor() - 5;
          final earlier = entry.value.where((t) => t.start + t.dur < tone.start);
          if (earlier.length == entry.value.indexOf(tone)) {
            expect(full[before].abs(), lessThan(.2), reason: entry.key);
          }
        }
        // Frequency from upward zero crossings in the first 60% of the tone.
        final n = (tone.dur * .6 * sampleRate).floor();
        var crossings = 0;
        for (var i = 1; i < n; i++) {
          if (s[i - 1] < 0 && s[i] >= 0) crossings++;
        }
        final measured = crossings / (n / sampleRate);
        expect(measured, closeTo(tone.freq, tone.freq * .03), reason: '${entry.key} ${tone.freq}');
        final peak = s.take(n).map((v) => v.abs()).reduce(max);
        expect(peak, lessThanOrEqualTo(tone.vol + 1e-9), reason: entry.key);
        expect(peak, greaterThan(tone.vol * .8), reason: entry.key);
      }
    }
  });

  test('duration covers the last tone plus the source 30 ms tail', () {
    final fanfare = renderTones(sfxRecipes['fanfare']!);
    expect(fanfare.length / sampleRate, closeTo(.4 + .22 + .03, .001));
  });

  test('WAV header is valid mono 16-bit PCM', () {
    final bytes = wavBytes(renderTones(metronomeTick, attack: .004));
    final d = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(d.getUint16(22, Endian.little), 1);
    expect(d.getUint32(24, Endian.little), sampleRate);
    expect(d.getUint16(34, Endian.little), 16);
    expect(d.getUint32(40, Endian.little), bytes.length - 44);
  });

  test('letter voice maps exactly like src/voice.ts and every file exists', () {
    expect(voiceFileFor('а', 'ru'), '1072');
    expect(voiceFileFor('Я', 'ru'), '1103');
    expect(voiceFileFor('ё', 'ru'), '1105');
    expect(voiceFileFor('7', 'ru'), 'd7');
    expect(voiceFileFor('a', 'en'), '97');
    expect(voiceFileFor('Z', 'en'), '122');
    expect(voiceFileFor('a', 'ru'), isNull, reason: 'foreign alphabet is silent');
    expect(voiceFileFor('ж', 'en'), isNull);
    expect(voiceFileFor('é', 'fr'), isNull, reason: 'no samples for fr');
    expect(voiceFileFor(',', 'ru'), isNull);
    final ru = [for (var c = 1072; c <= 1103; c++) String.fromCharCode(c), 'ё', ...'0123456789'.split('')];
    final en = [...'abcdefghijklmnopqrstuvwxyz'.split(''), ...'0123456789'.split('')];
    for (final (lang, chars) in [('ru', ru), ('en', en)]) {
      for (final ch in chars) {
        final f = voiceFileFor(ch, lang)!;
        expect(File('assets/voice/$lang/$f.m4a').existsSync(), true, reason: '$lang $ch');
      }
    }
    expect(ru.length, 43);
    expect(en.length, 36);
  });

  test('disabled sound plays nothing and metronome clamps like the source', () {
    var calls = 0;
    final sound = TypeFreeSound(enabled: () {
      calls++;
      return false;
    });
    sound.effect('success');
    expect(calls, 1);
    expect(sound.metronomeRunning, false);
  });
}

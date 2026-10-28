import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Port of src/sound.ts: quiet synthesized effects (no files) and the optional
/// metronome tick. Each recipe is rendered once into a mono 16-bit WAV.
enum Wave { sine, triangle, square }

class Tone {
  const Tone(
    this.freq,
    this.start,
    this.dur, [
    this.vol = 0.05,
    this.wave = Wave.sine,
    this.flat = false,
  ]);
  final double freq, start, dur, vol;
  final Wave wave;

  /// Constant gain without envelope (the error beep in src/main.ts).
  final bool flat;
}

const _vol = 0.05;

/// Exact recipes of `sfx` in src/sound.ts (frequency Hz, start s, duration s, volume, wave).
const Map<String, List<Tone>> sfxRecipes = {
  'success': [Tone(523.25, 0, .16, _vol), Tone(659.25, .08, .16, _vol)],
  'fanfare': [
    Tone(523.25, 0, .22, .06),
    Tone(587.33, .1, .22, .06),
    Tone(659.25, .2, .22, .06),
    Tone(783.99, .3, .22, .06),
    Tone(1046.5, .4, .22, .06),
  ],
  'star': [
    Tone(1318.5, 0, .14, .05, Wave.triangle),
    Tone(1760, .07, .14, .05, Wave.triangle),
  ],
  'start': [Tone(440, 0, .1, .04), Tone(660, .08, .12, .04)],
  'upgrade': [
    Tone(659.25, 0, .14, .05, Wave.triangle),
    Tone(880, .06, .14, .05, Wave.triangle),
    Tone(1108.7, .12, .14, .05, Wave.triangle),
  ],
  'record': [
    Tone(659.25, 0, .2, .06, Wave.triangle),
    Tone(880, .09, .2, .06, Wave.triangle),
    Tone(1046.5, .18, .2, .06, Wave.triangle),
    Tone(1318.5, .27, .2, .06, Wave.triangle),
  ],
  'catHappy': [Tone(700, 0, .1, .05), Tone(1000, .07, .14, .05)],
  'catSad': [Tone(420, 0, .12, .05), Tone(280, .09, .18, .05)],
};

/// Error beep from src/main.ts beep(): square 220 Hz, constant gain .06, 70 ms.
const errorBeep = [Tone(220, 0, .07, .06, Wave.square, true)];

/// Metronome tick: square 1600 Hz, 4 ms attack to .05, exponential to 50 ms.
const metronomeTick = [Tone(1600, 0, .05, .05, Wave.square)];

const sampleRate = 22050;

/// Renders tones with the Web Audio envelope used by the source: linear ramp
/// from .0001 to vol over [attack], exponential back to .0001 at start+dur.
Float64List renderTones(List<Tone> tones, {double attack = .012}) {
  final end = tones.map((t) => t.start + t.dur + .03).reduce(max);
  final out = Float64List((end * sampleRate).ceil());
  for (final t in tones) {
    final first = (t.start * sampleRate).round();
    final last = ((t.start + t.dur) * sampleRate).round();
    final a = max(1, (attack * sampleRate).round());
    for (var i = first; i < last && i < out.length; i++) {
      final n = i - first;
      final time = n / sampleRate;
      double gain;
      if (t.flat) {
        gain = t.vol;
      } else if (n < a) {
        gain = .0001 + (t.vol - .0001) * n / a;
      } else {
        final p = (n - a) / max(1, last - first - a);
        gain = t.vol * pow(.0001 / t.vol, p);
      }
      final phase = (t.freq * time) % 1.0;
      final s = switch (t.wave) {
        Wave.sine => sin(2 * pi * phase),
        Wave.triangle => 1 - 4 * (phase - .5).abs(),
        Wave.square => phase < .5 ? 1.0 : -1.0,
      };
      out[i] += s * gain;
    }
  }
  return out;
}

Uint8List wavBytes(Float64List samples) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(
      44 + i * 2,
      (samples[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

/// Player for effects and metronome. Silent when disabled or when the
/// platform has no audio; never throws into the typing flow.
class TypeFreeSound {
  TypeFreeSound({required this.enabled});
  bool Function() enabled;
  final _cache = <String, Uint8List>{};
  final _players = <AudioPlayer>[];
  var _next = 0;
  Timer? _metro;
  int? _bpm;

  Uint8List _bytes(String key, List<Tone> tones, {double attack = .012}) =>
      _cache[key] ??= wavBytes(renderTones(tones, attack: attack));

  /// Widget tests have no audio plugin; sound is a no-op under the test binding.
  static bool get _testBinding =>
      WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');

  Future<void> _play(Uint8List bytes) async {
    if (_testBinding) return;
    try {
      if (_players.length < 4) _players.add(AudioPlayer());
      final p = _players[_next++ % _players.length];
      await p.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Нет аудио — молча, как в исходнике.
    }
  }

  void effect(String name) {
    if (!enabled()) return;
    final recipe = name == 'error' ? errorBeep : sfxRecipes[name];
    if (recipe != null) unawaited(_play(_bytes(name, recipe)));
  }

  /// Source: start(bpm) clamps to 40..240, ticks immediately, then on interval.
  void startMetronome(int bpm) {
    final clamped = bpm.clamp(40, 240);
    if (_metro != null && _bpm == clamped) return;
    stopMetronome();
    _bpm = clamped;
    final tick = _bytes('tick', metronomeTick, attack: .004);
    unawaited(_play(tick));
    _metro = Timer.periodic(
      Duration(microseconds: (60000000 / clamped).round()),
      (_) => unawaited(_play(tick)),
    );
  }

  void stopMetronome() {
    _metro?.cancel();
    _metro = null;
    _bpm = null;
  }

  bool get metronomeRunning => _metro != null;

  /// «Озвучка букв»: off by default, independent of the effects switch.
  bool Function() voiceEnabled = () => false;

  /// Says a correctly typed letter or digit in the interface language.
  void speak(String ch, String language) {
    if (!voiceEnabled() || _testBinding) return;
    final file = voiceFileFor(ch, language);
    if (file == null) return;
    unawaited(() async {
      try {
        if (_players.length < 4) _players.add(AudioPlayer());
        final p = _players[_next++ % _players.length];
        await p.play(AssetSource('voice/$language/$file.m4a'));
      } catch (_) {
        // Нет аудио — молча.
      }
    }());
  }

  Future<void> dispose() async {
    stopMetronome();
    for (final p in _players) {
      await p.dispose();
    }
    _players.clear();
  }
}

/// Port of src/voice.ts fileFor(): offline Silero samples, RU/EN only.
/// RU: Unicode code of а–я (1072–1103) and ё (1105); EN: code of a–z (97–122);
/// digits: 'd' + digit. Anything else (other languages, symbols) is silent.
const voicedLanguages = {'ru', 'en'};
String? voiceFileFor(String ch, String language) {
  if (ch.isEmpty || !voicedLanguages.contains(language)) return null;
  final first = ch.substring(0, 1);
  if (RegExp(r'^[0-9]$').hasMatch(first)) return 'd$first';
  final code = first.toLowerCase().codeUnitAt(0);
  if (language == 'ru' && ((code >= 1072 && code <= 1103) || code == 1105)) {
    return '$code';
  }
  if (language == 'en' && code >= 97 && code <= 122) return '$code';
  return null;
}

/// One instance for the whole app (as the source module-level `sfx`).
/// Disabled until the app binds it to the user's «Звук» setting, so tests
/// and headless runs never touch the audio plugin.
final appSound = TypeFreeSound(enabled: () => false);

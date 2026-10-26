import 'dart:convert';

const _langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
const _banks = [
  'classic',
  'poemHymn',
  'ruWords',
  'ruPhrases',
  'digits',
  'abandon',
  'engRus',
  'letterByLetter',
];
const _boolKeys = {
  'tr_hide',
  'tr_sound',
  'tr_voice',
  'tr_block',
  'tr_keyb',
  'tr_heat',
  'tr_hardkeys',
  'tr_bridge',
  'tr_metro',
  'tr_dark',
  'tr_flow',
  'tr_pet',
  'typefree_practice_plain',
};
bool _finite(Object? n) => n is num && n.isFinite && n >= 0;
void validateLegacyValue(String key, String raw) {
  if (raw.length > 1000000) throw const FormatException('Oversized value');
  if (_boolKeys.contains(key)) {
    if (!['0', '1'].contains(raw)) {
      throw const FormatException('Invalid boolean');
    }
    return;
  }
  if (key == 'tr_profile') {
    if (!['m', 'f', 'kids'].contains(raw)) {
      throw const FormatException('Invalid profile');
    }
    return;
  }
  if (key == 'tr_lang') {
    if (!_langs.contains(raw)) throw const FormatException('Invalid language');
    return;
  }
  if (key == 'tr_layout') {
    if (!['auto', 'qwerty', 'azerty', 'qwertz'].contains(raw)) {
      throw const FormatException('Invalid layout');
    }
    return;
  }
  if (key == 'tr_mode') {
    if (!['trainer', 'companion'].contains(raw)) {
      throw const FormatException('Invalid mode');
    }
    return;
  }
  if (key == 'typefree_practice_bank' || key == 'typefree_practice_text_bank') {
    if (!_banks.contains(raw)) throw const FormatException('Invalid bank');
    return;
  }
  final v = jsonDecode(raw);
  if (key == 'tr_history') {
    const fields = {'t', 'wpm', 'acc', 'len', 'ms', 'err', 'score'};
    if (v is! List ||
        v.length > 10000 ||
        !v.every(
          (x) =>
              x is Map &&
              x.keys.toSet().difference(fields).isEmpty &&
              ['t', 'wpm', 'acc'].every(x.containsKey) &&
              x.values.every(_finite) &&
              (x['acc'] as num) <= 100,
        )) {
      throw const FormatException('Invalid history');
    }
    return;
  }
  if (key.startsWith('tr_progress_')) {
    if (v is! Map ||
        v.keys.toSet().difference({
          'bestWpm',
          'bestAcc',
          'done',
          'lastIdx',
        }).isNotEmpty ||
        !['bestWpm', 'bestAcc', 'lastIdx'].every((k) => _finite(v[k])) ||
        v['lastIdx'] is! int ||
        (v['bestAcc'] as num) > 100 ||
        v['done'] is! List ||
        !(v['done'] as List).every((s) => s is String && s.length <= 100)) {
      throw const FormatException('Invalid progress');
    }
    return;
  }
  if (key == 'tr_kids' || key.startsWith('tr_course_')) {
    if (v is! Map ||
        v.keys.toSet().difference({'stars'}).isNotEmpty ||
        v['stars'] is! Map ||
        !(v['stars'] as Map).values.every(
          (x) => x is int && x >= 0 && x <= 3,
        )) {
      throw const FormatException('Invalid stars');
    }
    return;
  }
  if (key == 'tr_ach') {
    if (v is! List ||
        v.length > 1000 ||
        !v.every(
          (s) => s is String && RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(s),
        )) {
      throw const FormatException('Invalid achievements');
    }
    return;
  }
  if (key == 'tr_keystats') {
    const fields = {'ok', 'err', 't', 'nt', 'bt', 'ts'};
    if (v is! Map ||
        !v.entries.every(
          (e) =>
              e.key is String &&
              RegExp(r'^[a-zA-Z0-9_-]{1,40}$').hasMatch(e.key as String) &&
              e.value is Map &&
              (e.value as Map).keys.toSet().difference(fields).isEmpty &&
              (e.value as Map).values.every(_finite),
        )) {
      throw const FormatException('Invalid keyboard stats');
    }
    return;
  }
  if (key == 'tr_compete') {
    if (v is! Map || !v.values.every(_finite)) {
      throw const FormatException('Invalid competition');
    }
    return;
  }
  if (!_finite(v)) throw const FormatException('Invalid numeric value');
}

bool safeLegacyKey(String k) =>
    _boolKeys.contains(k) ||
    {
      'tr_profile',
      'tr_lang',
      'tr_layout',
      'tr_mode',
      'typefree_practice_bank',
      'typefree_practice_text_bank',
      'tr_history',
      'tr_kids',
      'tr_kids_ai_lvl',
      'tr_span_best',
      'tr_compete',
      'tr_ach',
      'tr_keystats',
      'tr_target_wpm',
      'tr_metro_bpm',
      'tr_mem_len',
      'tr_pet_streak',
    }.contains(k) ||
    _langs.any((l) => k == 'tr_course_$l') ||
    _banks.any((b) => k == 'tr_progress_$b' || k == 'tr_progress_${b}_plain');

/// Old source uses 0/1 strings and shares bank progress independently of language.
Map<String, dynamic> legacyPracticePreferences(Map<String, dynamic> values) {
  final result = <String, dynamic>{};
  for (final e in {
    'tr_lang': 'lang',
    'tr_profile': 'profile',
    'tr_layout': 'layout',
  }.entries) {
    if (values[e.key] != null) result[e.value] = values[e.key];
  }
  for (final e in {
    'tr_block': 'block',
    'tr_keyb': 'keyboard',
    'tr_heat': 'heat',
    'tr_bridge': 'bridge',
    'tr_flow': 'flow',
    'tr_pet': 'pet',
    'typefree_practice_plain': 'plain',
  }.entries) {
    if (values[e.key] != null) result[e.value] = values[e.key] == '1';
  }
  const visible = {'classic', 'poemHymn', 'ruWords', 'ruPhrases', 'digits'};
  final fallback = values['tr_lang'] == 'ru' ? 'ruWords' : 'classic';
  final bank = values['typefree_practice_bank'];
  result['bank'] = visible.contains(bank) ? bank : fallback;
  final textBank = values['typefree_practice_text_bank'];
  result['textBank'] = visible.contains(textBank) && textBank != 'digits'
      ? textBank
      : fallback;
  final key =
      'tr_progress_${result['bank']}${result['plain'] == true && result['bank'] != 'digits' ? '_plain' : ''}';
  if (values[key] is String) {
    result['index'] = (jsonDecode(values[key] as String) as Map)['lastIdx'];
  }
  return result;
}

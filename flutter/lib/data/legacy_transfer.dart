import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'local_repository.dart';

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
Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return v.map(_sorted).toList();
  return v;
}

String _digest(Object? v) =>
    sha256.convert(utf8.encode(jsonEncode(_sorted(v)))).toString();
bool _finite(Object? n) => n is num && n.isFinite && n >= 0;
void _valid(String key, String raw) {
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
              x.values.every(_finite),
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

/// Explicit local transfer only. No vault/PIN/device ID/queue, no automatic upload.
Map<String, dynamic> createTransfer(
  Map<String, String> raw, {
  required String exportId,
}) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(exportId)) {
    throw const FormatException('Invalid export ID');
  }
  final values = <String, String>{};
  for (final e in raw.entries) {
    if (!safeLegacyKey(e.key)) continue;
    _valid(e.key, e.value);
    values[e.key] = e.value;
  }
  final body = {
    'schema': 'typerighting.local-transfer/1',
    'exportId': exportId,
    'sourceBuild': '2.60.4',
    'values': values,
  };
  return {...body, 'sha256': _digest(body)};
}

Future<bool> importTransfer(
  LocalRepository repo,
  Map<String, dynamic> envelope,
) async {
  if (envelope.keys.toSet().difference({
        'schema',
        'exportId',
        'sourceBuild',
        'values',
        'sha256',
      }).isNotEmpty ||
      envelope['schema'] != 'typerighting.local-transfer/1' ||
      envelope['exportId'] is! String ||
      !RegExp(r'^[a-zA-Z0-9_-]{1,80}$')
          .hasMatch(envelope['exportId'] as String) ||
      envelope['values'] is! Map ||
      envelope['sourceBuild'] != '2.60.4') {
    throw const FormatException('Invalid transfer');
  }
  final body = {
    for (final e in envelope.entries)
      if (e.key != 'sha256') e.key: e.value,
  };
  if (_digest(body) != envelope['sha256']) {
    throw const FormatException('Checksum mismatch');
  }
  final values = Map<String, dynamic>.from(envelope['values'] as Map);
  for (final e in values.entries) {
    if (!safeLegacyKey(e.key) || e.value is! String) {
      throw const FormatException('Forbidden key');
    }
    _valid(e.key, e.value as String);
  }
  var inserted = false;
  await repo.transaction((doc) {
    final receipts = doc['receipts'] as Map, legacy = doc['legacy'] as Map;
    final id = envelope['exportId'] as String;
    if (receipts.containsKey(id)) {
      if (receipts[id] != envelope['sha256']) {
        throw const FormatException('Reused ID with changed content');
      }
      return;
    }
    for (final e in values.entries) {
      if (legacy.containsKey(e.key) && legacy[e.key] != e.value) {
        throw const FormatException(
          'Existing progress conflict; original retained',
        );
      }
    }
    legacy.addAll(values);
    receipts[id] = envelope['sha256'];
    inserted = true;
  });
  return inserted;
}

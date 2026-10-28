import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'local_repository.dart';
import 'legacy_values.dart';
export 'legacy_values.dart' show safeLegacyKey, legacyPracticePreferences;

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
    validateLegacyValue(e.key, e.value);
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

/// Checks a transfer file without writing anything (I5 step 1): format,
/// source build, checksum and every value. Returns the values to import.
Map<String, dynamic> verifyTransfer(Map<String, dynamic> envelope) {
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
    validateLegacyValue(e.key, e.value as String);
  }
  return values;
}

Future<bool> importTransfer(
  LocalRepository repo,
  Map<String, dynamic> envelope,
) async {
  final values = verifyTransfer(envelope);
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
    final archive =
        doc.putIfAbsent('legacyArchive', () => <String, dynamic>{}) as Map;
    for (final e in values.entries) {
      archive.putIfAbsent(e.key, () => e.value);
    }
    // Fill missing preferences only; importing never silently replaces an existing choice.
    final prefs = doc['prefs'] as Map;
    for (final e in legacyPracticePreferences(values).entries) {
      if (e.key == 'index' &&
          prefs['bank'] != legacyPracticePreferences(values)['bank']) {
        continue;
      }
      prefs.putIfAbsent(e.key, () => e.value);
    }
    receipts[id] = envelope['sha256'];
    inserted = true;
  });
  return inserted;
}

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'string_store.dart';
import 'legacy_values.dart';

const candidateDataKey = 'typefree.flutter.candidate.v1';

/// One transactional document for this isolated candidate, not the old app store.
/// A failed write never publishes half a session/import in memory.
class LocalRepository {
  LocalRepository(this.store);
  final StringStore store;
  Map<String, dynamic> _data = {
    'schema': 1,
    'legacy': <String, dynamic>{},
    'legacyArchive': <String, dynamic>{},
    'sessions': <dynamic>[],
    'receipts': <String, dynamic>{},
    'prefs': <String, dynamic>{},
  };
  Future<void> _tail = Future.value();
  Map<String, dynamic> get data =>
      jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
  Future<void> load() async {
    final raw = await store.read(candidateDataKey);
    if (raw == null) return;
    final doc = jsonDecode(raw);
    if (doc is! Map<String, dynamic> ||
        doc['schema'] != 1 ||
        doc['sessions'] is! List ||
        doc['legacy'] is! Map ||
        doc['prefs'] is! Map ||
        doc['receipts'] is! Map) {
      throw const FormatException('Invalid saved document; original preserved');
    }
    for (final map in [
      doc['legacy'],
      doc['legacyArchive'] ?? <String, dynamic>{},
    ]) {
      if (map is! Map) throw const FormatException('Invalid legacy archive');
      for (final e in map.entries) {
        if (e.key is! String ||
            !(safeLegacyKey(e.key as String) ||
                e.key == 'tr_progress_custom' ||
                e.key == 'tr_progress_custom_plain') ||
            e.value is! String) {
          throw const FormatException(
            'Invalid archived value; original preserved',
          );
        }
        validateLegacyValue(e.key as String, e.value as String);
      }
    }
    final pending = doc['webviewPending'] ?? <String, dynamic>{};
    if (pending is! Map) {
      throw const FormatException('Invalid pending WebView recovery data');
    }
    for (final snapshot in pending.entries) {
      if (snapshot.key is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(snapshot.key as String) ||
          snapshot.value is! Map) {
        throw const FormatException(
          'Invalid pending WebView recovery snapshot',
        );
      }
      for (final entry in (snapshot.value as Map).entries) {
        if (entry.key is! String ||
            !safeLegacyKey(entry.key as String) ||
            entry.value is! String) {
          throw const FormatException('Invalid pending WebView recovery value');
        }
        validateLegacyValue(entry.key as String, entry.value as String);
      }
      final values = Map<String, dynamic>.from(snapshot.value as Map);
      final keys = values.keys.toList()..sort();
      if (keys.isEmpty ||
          sha256
                  .convert(
                    utf8.encode(
                      jsonEncode({for (final key in keys) key: values[key]}),
                    ),
                  )
                  .toString() !=
              snapshot.key) {
        throw const FormatException(
          'Invalid pending WebView recovery checksum',
        );
      }
    }
    for (final e in (doc['receipts'] as Map).entries) {
      if (e.key is! String ||
          e.value is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(e.value as String)) {
        throw const FormatException('Invalid import receipt');
      }
    }
    final prefs = doc['prefs'] as Map;
    final flutterAchievements = prefs['flutterAchievements'];
    if (flutterAchievements != null &&
        (flutterAchievements is! List ||
            flutterAchievements.length > 100 ||
            !flutterAchievements.every(
              (id) =>
                  id is String &&
                  RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id),
            ))) {
      throw const FormatException('Invalid local achievements');
    }
    final invalidKeys = prefs['webviewInvalidKeys'];
    if (invalidKeys != null &&
        (invalidKeys is! List ||
            !invalidKeys.every((key) => key is String && safeLegacyKey(key)))) {
      throw const FormatException('Invalid migration issue list');
    }
    final legacyName = prefs['legacyCertificateName'];
    if (legacyName != null &&
        (legacyName is! String || legacyName.length > 1000000)) {
      throw const FormatException('Invalid preserved legacy name');
    }
    for (final profile in ['m', 'f', 'kids']) {
      final name = prefs['certificateName_$profile'];
      if (name != null && (name is! String || name.length > 512)) {
        throw const FormatException('Invalid local certificate name');
      }
    }
    for (final key in [
      'plain',
      'block',
      'bridge',
      'flow',
      'keyboard',
      'pet',
      'motion',
      'heat',
      'hardkeys',
    ]) {
      if (prefs.containsKey(key) && prefs[key] is! bool) {
        throw const FormatException('Invalid saved option');
      }
    }
    for (final e in <String, Set<String>>{
      'lang': {'ru', 'en', 'es', 'de', 'fr', 'it', 'pt'},
      'profile': {'m', 'f', 'kids'},
      'layout': {'auto', 'qwerty', 'azerty', 'qwertz'},
      'bank': {'classic', 'poemHymn', 'ruWords', 'ruPhrases', 'digits'},
      'textBank': {'classic', 'poemHymn', 'ruWords', 'ruPhrases'},
    }.entries) {
      if (prefs.containsKey(e.key) && !e.value.contains(prefs[e.key])) {
        throw const FormatException('Invalid saved selection');
      }
    }
    if (prefs.containsKey('index') &&
        (prefs['index'] is! int || (prefs['index'] as int) < 0)) {
      throw const FormatException('Invalid resume index');
    }
    final ids = <String>{};
    for (final row in doc['sessions'] as List) {
      if (row is! Map ||
          row['id'] is! String ||
          !ids.add(row['id'] as String) ||
          ![
            'title',
            'exercise',
            'language',
            'profile',
            'mode',
            'difficulty',
          ].every((k) => row[k] is String) ||
          !['t', 'wpm', 'accuracy', 'errors', 'elapsedMs', 'len'].every(
            (k) =>
                row[k] is num &&
                (row[k] as num).isFinite &&
                (row[k] as num) >= 0,
          ) ||
          (row['accuracy'] as num) > 100) {
        throw const FormatException(
          'Invalid saved session; original preserved',
        );
      }
      if (row.containsKey('errKeys')) {
        final errors = row['errKeys'];
        if (errors is! Map ||
            !errors.entries.every(
              (e) =>
                  e.key is String &&
                  RegExp(r'^[a-zA-Z0-9_-]{1,40}$').hasMatch(e.key as String) &&
                  e.value is int &&
                  (e.value as int) >= 0,
            )) {
          throw const FormatException(
            'Invalid session key errors; original preserved',
          );
        }
      }
    }
    _data = doc;
  }

  Future<void> transaction(void Function(Map<String, dynamic>) apply) {
    final operation = _tail.then((_) async {
      final copy = data;
      apply(copy);
      await store.write(candidateDataKey, jsonEncode(copy));
      _data = copy;
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<bool> appendSession(Map<String, dynamic> session) async {
    var inserted = false;
    await transaction((doc) {
      final list = doc['sessions'] as List;
      if (list.any((row) => row['id'] == session['id'])) return;
      list.add(session);
      inserted = true;
    });
    return inserted;
  }
}

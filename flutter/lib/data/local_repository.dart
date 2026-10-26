import 'dart:convert';

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
    for (final e in (doc['receipts'] as Map).entries) {
      if (e.key is! String ||
          e.value is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(e.value as String)) {
        throw const FormatException('Invalid import receipt');
      }
    }
    final prefs = doc['prefs'] as Map;
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

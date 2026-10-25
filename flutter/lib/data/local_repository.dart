import 'dart:convert';

import 'string_store.dart';

const candidateDataKey = 'typefree.flutter.candidate.v1';

/// One transactional document for this isolated candidate, not the old app store.
/// A failed write never publishes half a session/import in memory.
class LocalRepository {
  LocalRepository(this.store);
  final StringStore store;
  Map<String, dynamic> _data = {
    'schema': 1,
    'legacy': <String, dynamic>{},
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

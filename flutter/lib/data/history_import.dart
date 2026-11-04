import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'legacy_values.dart';
import 'local_repository.dart';
import 'string_store.dart';

class _ReadOnlyStore implements StringStore {
  _ReadOnlyStore(this.raw);
  final String raw;
  @override
  Future<String?> read(String key) async => raw;
  @override
  Future<void> write(String key, String value) =>
      throw UnsupportedError('read only');
}

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _sorted(value[k])};
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}

/// Validates the exported history before a transaction; old rows are kept as
/// separate recovery copies because they have no stable session identifiers.
class HistoryImport {
  HistoryImport._(this.sessions, this.copies, this.hasUnresolvedCopies);
  final List<Map<String, dynamic>> sessions;
  final List<String> copies;
  final bool hasUnresolvedCopies;
  int get count =>
      sessions.length +
      copies.fold(0, (n, s) => n + (jsonDecode(s) as List).length);

  static Future<HistoryImport> verify(Map<String, dynamic> file) async {
    if (file['schema'] != 'typefree.history/1' ||
        file['exportedAt'] is! num ||
        file['sessions'] is! List ||
        file.keys.toSet().difference({
          'schema',
          'exportedAt',
          'sessions',
          'unresolvedHistoryCopies',
        }).isNotEmpty ||
        jsonEncode(file).length > 10000000) {
      throw const FormatException('Invalid history file');
    }
    final sessions = <Map<String, dynamic>>[];
    final old = <Map<String, dynamic>>[];
    const oldFields = {'t', 'wpm', 'acc', 'len', 'ms', 'err', 'score'};
    for (final value in file['sessions'] as List) {
      if (value is! Map ||
          !value.keys.every((key) => key is String) ||
          (value['origin'] != 'flutter' && value['origin'] != 'legacy')) {
        throw const FormatException('Invalid history row');
      }
      final row = Map<String, dynamic>.from(value);
      if (row.remove('origin') == 'flutter') {
        sessions.add(row);
      } else {
        // Legacy export adds an ID and normalized accuracy for display. Do
        // not silently discard other fields from a newer or modified file.
        if (row.keys.toSet().difference({
          ...oldFields,
          'id',
          'accuracy',
        }).isNotEmpty) {
          throw const FormatException('Unsupported legacy history fields');
        }
        old.add({
          for (final e in row.entries)
            if (oldFields.contains(e.key)) e.key: e.value,
        });
      }
    }
    final copies = <String>[];
    void addCopy(Object? rows) {
      if (rows is! List) throw const FormatException('Invalid history copy');
      final raw = jsonEncode(rows);
      validateLegacyValue('tr_history', raw);
      if (rows.isNotEmpty) copies.add(raw);
    }

    addCopy(old);
    final unresolved = file['unresolvedHistoryCopies'] ?? [];
    if (unresolved is! List || unresolved.length > 100) {
      throw const FormatException('Invalid recovery copies');
    }
    for (final rows in unresolved) {
      addCopy(rows);
    }
    final validation = LocalRepository(
      _ReadOnlyStore(
        jsonEncode({
          'schema': 1,
          'legacy': {},
          'sessions': sessions,
          'prefs': {},
          'receipts': {},
        }),
      ),
    );
    await validation.load();
    return HistoryImport._(sessions, copies, unresolved.isNotEmpty);
  }

  Future<bool> apply(LocalRepository repo) async {
    var changed = false;
    await repo.transaction((doc) {
      final current = doc['sessions'] as List;
      final legacy = doc['legacy'] as Map;
      final archive =
          doc.putIfAbsent('legacyArchive', () => <String, dynamic>{}) as Map;
      final pending =
          doc.putIfAbsent('webviewPending', () => <String, dynamic>{}) as Map;
      // A single old timeline on an otherwise empty target is unambiguous and
      // can be shown in normal statistics. Anything else stays separate: old
      // rows have no stable IDs and must not be counted twice by guessing.
      final canRestoreTimeline =
          current.isEmpty &&
          !legacy.containsKey('tr_history') &&
          !archive.containsKey('tr_history') &&
          pending.isEmpty &&
          !hasUnresolvedCopies &&
          copies.length == 1;
      for (final row in sessions) {
        final existing = current.where((v) => v['id'] == row['id']).toList();
        if (existing.isNotEmpty) {
          if (jsonEncode(_sorted(existing.single)) !=
              jsonEncode(_sorted(row))) {
            throw const FormatException('Conflicting session ID');
          }
        } else {
          current.add(row);
          changed = true;
        }
      }
      for (final raw in copies) {
        if (canRestoreTimeline) {
          archive['tr_history'] = raw;
          changed = true;
          continue;
        }
        // A repeat of the same import must not create a second recovery copy.
        if (archive['tr_history'] == raw) continue;
        final snapshot = {'tr_history': raw};
        final id = sha256.convert(utf8.encode(jsonEncode(snapshot))).toString();
        if (!pending.containsKey(id)) {
          pending[id] = snapshot;
          changed = true;
        }
      }
    });
    return changed;
  }
}

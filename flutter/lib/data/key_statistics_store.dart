import 'dart:async';
import 'dart:convert';

import '../domain/key_statistics.dart';
import 'local_repository.dart';

/// Debounced key evidence and completion share the repository's atomic document.
/// Failed batches remain queued in order; retry never repeats a committed batch.
class KeyStatisticsStore {
  KeyStatisticsStore(this.repository);
  final LocalRepository repository;
  final recorder = KeyRecorder();
  final _pending = <KeyEvidence>[];
  Future<void> _tail = Future.value();
  Timer? _timer;
  Object? lastError;
  bool _disposed = false;

  void record(String id, bool ok, int now, {bool timed = true}) {
    if (_disposed) return;
    _pending.add(recorder.record(id, ok, now, timed: timed));
    _timer ??= Timer(const Duration(milliseconds: 800), () {
      _timer = null;
      unawaited(
        flush().catchError((Object error) {
          lastError = error;
        }),
      );
    });
  }

  Future<void> flush() => commit((_) {});

  Future<void> commit(void Function(Map<String, dynamic>) apply) {
    _timer?.cancel();
    _timer = null;
    final result = _tail.then((_) async {
      final batch = List<KeyEvidence>.of(_pending);
      await repository.transaction((doc) {
        final legacy = doc['legacy'] as Map;
        final stats = legacy['tr_keystats'] is String
            ? Map<String, dynamic>.from(
                jsonDecode(legacy['tr_keystats'] as String) as Map,
              )
            : <String, dynamic>{};
        for (final event in batch) {
          applyKeyEvidence(stats, event);
        }
        if (batch.isNotEmpty) legacy['tr_keystats'] = jsonEncode(stats);
        apply(doc);
      });
      _pending.removeRange(0, batch.length);
      lastError = null;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_pending.isNotEmpty) {
      unawaited(
        flush().catchError((Object error) {
          lastError = error;
        }),
      );
    }
  }
}

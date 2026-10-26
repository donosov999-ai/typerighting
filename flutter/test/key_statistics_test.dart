import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/key_statistics.dart';
import 'package:typefree_flutter_foundation/data/key_statistics_store.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';

import 'storage_transfer_test.dart' show MemoryStore;

class HeldStore extends MemoryStore {
  final entered = Completer<void>(), release = Completer<void>();
  bool held = true;
  @override
  Future<void> write(String key, String value) async {
    if (held) {
      entered.complete();
      await release.future;
      held = false;
    }
    await super.write(key, value);
  }
}

void closeTree(dynamic actual, dynamic expected) {
  if (expected is num) {
    expect(actual, closeTo(expected, 1e-8));
  } else if (expected is Map) {
    expect((actual as Map).keys.toSet(), expected.keys.toSet());
    for (final k in expected.keys) {
      closeTree(actual[k], expected[k]);
    }
  } else if (expected is List) {
    expect((actual as List).length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      closeTree(actual[i], expected[i]);
    }
  } else {
    expect(actual, expected);
  }
}

void main() {
  test('1474 events match original TS counters, EMA, decay, gaps, history and heat', () {
    final fixture = jsonDecode(
      File('test/fixtures/key-statistics.json').readAsStringSync(),
    ) as Map;
    for (final c in fixture['cases'] as List) {
      final recorder = KeyRecorder(), history = <dynamic>[];
      final stats = Map<String, dynamic>.from((c['initial'] as Map?) ?? {});
      final events = c['events'] as List;
      for (var i = 0; i < events.length; i++) {
        final e = events[i] as Map;
        if (e['push'] == true) {
          final captured = recorder.take(e['at'] as int);
          if (captured.eligible(e['wpm'] as int)) {
            history.add(
              captured.point(e['wpm'] as int, e['acc'] as num, e['at'] as int),
            );
          }
        } else {
          applyKeyEvidence(
            stats,
            recorder.record(
              e['id'] as String,
              e['ok'] as bool,
              e['at'] as int,
              timed: e['timed'] != false,
            ),
          );
        }
        closeTree(stats, c['expected'][i]['stats']);
        closeTree(history, c['expected'][i]['history']);
      }
      closeTree(keyHeatMap(stats), c['result']['heat']);
    }
  });
  test(
    'failed flush retries once, frozen imported archive never changes',
    () async {
      final store = MemoryStore();
      final live = LocalRepository(store);
      await live.transaction((d) {
        d['legacyArchive'] = {'tr_keystats': '{"a":{"ok":6,"err":2}}'};
        (d['legacy'] as Map)['tr_keystats'] = '{"a":{"ok":6,"err":2}}';
      });
      final stats = KeyStatisticsStore(live);
      stats.record('a', false, 100000);
      store.fail = true;
      await expectLater(stats.flush(), throwsA(isA<StateError>()));
      expect(jsonDecode(live.data['legacy']['tr_keystats'])['a']['err'], 2);
      stats.record('a', true, 100100);
      store.fail = false;
      await stats.flush();
      await stats.flush();
      final reload = LocalRepository(store);
      await reload.load();
      expect(jsonDecode(reload.data['legacy']['tr_keystats'])['a']['err'], 3);
      expect(jsonDecode(reload.data['legacy']['tr_keystats'])['a']['ok'], 7);
      expect(
        reload.data['legacyArchive']['tr_keystats'],
        '{"a":{"ok":6,"err":2}}',
      );
      stats.dispose();
    },
  );
  test(
    'completion failure retains frozen error keys and queued evidence',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      final service = KeyStatisticsStore(repo);
      for (var i = 0; i < 12; i++) {
        service.record('d1', i != 3, 100000 + i * 100);
      }
      final captured = service.recorder.take(101200);
      expect(captured.len, 12);
      expect(captured.errorKeys, {'d1': 1});
      store.fail = true;
      void apply(Map<String, dynamic> doc) {
        (doc['legacy'] as Map)['tr_history'] = jsonEncode([
          captured.point(40, 92, 101200),
        ]);
      }

      await expectLater(service.commit(apply), throwsA(isA<StateError>()));
      expect(repo.data['legacy'], isEmpty);
      store.fail = false;
      await service.commit(apply);
      await service.flush();
      expect(jsonDecode(repo.data['legacy']['tr_keystats'])['d1']['ok'], 11);
      expect(jsonDecode(repo.data['legacy']['tr_history'])[0]['len'], 12);
      service.dispose();
    },
  );
  test(
    'overlapping flushes and input during a write count each key once',
    () async {
      final store = HeldStore();
      final live = LocalRepository(store);
      final stats = KeyStatisticsStore(live);
      stats.record('a', true, 100000);
      final first = stats.flush();
      await store.entered.future;
      stats.record('a', false, 100100);
      final second = stats.flush();
      store.release.complete();
      await Future.wait([first, second]);
      final keys = jsonDecode(live.data['legacy']['tr_keystats']);
      expect(keys['a']['ok'], 1);
      expect(keys['a']['err'], 1);
      stats.dispose();
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/string_store.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/legacy_transfer.dart';

class MemoryStore implements StringStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('simulated disk failure');
    values[key] = value;
  }
}

void main() {
  final original = <String, String>{
    'tr_history': jsonEncode([
      {'t': 1700000000000, 'wpm': 42, 'acc': 97, 'len': 45},
    ]),
    'tr_progress_ruWords': jsonEncode({
      'bestWpm': 42,
      'bestAcc': 97,
      'done': ['ruw-1'],
      'lastIdx': 1,
    }),
    'tr_progress_abandon': jsonEncode({
      'bestWpm': 20,
      'bestAcc': 90,
      'done': ['old-1'],
      'lastIdx': 0,
    }),
    'tr_course_ru': jsonEncode({
      'stars': {'1': 3},
    }),
    'tr_kids': jsonEncode({
      'stars': {'0': 2},
    }),
    'tr_keystats': jsonEncode({
      'a': {'ok': 12, 'err': 2, 't': 130, 'bt': 110, 'nt': 10},
    }),
    'tr_ach': jsonEncode(['first', 'wpm30']),
    'tr_lang': 'ru',
    'tr_profile': 'f',
    'tr_dark': '0',
    'typefree_practice_plain': '1',
    'typefree_practice_bank': 'ruWords',
    'tr_span_best': '5',
    'tr_acc': 'test credential - must never enter transfer',
    'tr_device': 'test device - must not migrate',
    'tr_sess_queue': '[]',
    'typefree_coach_diagnostic_outbox_v1': '[]',
  };
  test('allowlisted source export preserves data and excludes auth/device/coach transport', () {
    final before = Map<String, String>.from(original);
    final e = createTransfer(original, exportId: 'fixture-1');
    expect(original, before);
    expect((e['values'] as Map).containsKey('tr_acc'), false);
    expect((e['values'] as Map).containsKey('tr_device'), false);
    expect((e['values'] as Map).containsKey('tr_sess_queue'), false);
    expect(
      (e['values'] as Map).containsKey('typefree_coach_diagnostic_outbox_v1'),
      false,
    );
    expect((e['values'] as Map)['tr_history'], original['tr_history']);
  });
  test(
    'atomic import, restart and repeated import do not duplicate history',
    () async {
      final store = MemoryStore(), r = LocalRepository(MemoryStore());
      final repo = LocalRepository(store);
      await repo.load();
      final e = createTransfer(original, exportId: 'fixture-1');
      expect(await importTransfer(repo, e), true);
      final after = repo.data;
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data, after);
      expect(await importTransfer(reload, e), false);
      expect(reload.data, after);
      expect(r.data['sessions'], isEmpty);
    },
  );
  test(
    'interrupted write commits neither values nor receipt, retry succeeds',
    () async {
      final store = MemoryStore(),
          e = createTransfer(original, exportId: 'fixture-2');
      final repo = LocalRepository(store);
      await repo.load();
      final before = repo.data;
      store.fail = true;
      await expectLater(importTransfer(repo, e), throwsStateError);
      expect(repo.data, before);
      expect(store.values, isEmpty);
      store.fail = false;
      expect(await importTransfer(repo, e), true);
    },
  );
  test(
    'checksum or reused-ID conflict preserves all existing progress',
    () async {
      final repo = LocalRepository(MemoryStore());
      final e = createTransfer(original, exportId: 'fixture-3');
      await importTransfer(repo, e);
      final before = repo.data;
      final corrupt = jsonDecode(jsonEncode(e)) as Map<String, dynamic>;
      (corrupt['values'] as Map)['tr_dark'] = '1';
      await expectLater(importTransfer(repo, corrupt), throwsFormatException);
      final reused = createTransfer({
        ...original,
        'tr_dark': '1',
      }, exportId: 'fixture-3');
      await expectLater(importTransfer(repo, reused), throwsFormatException);
      expect(repo.data, before);
    },
  );
  test(
    'existing-key conflict has no partial import even with new keys',
    () async {
      final repo = LocalRepository(MemoryStore());
      await importTransfer(
        repo,
        createTransfer({'tr_lang': 'en'}, exportId: 'old'),
      );
      final before = repo.data;
      await expectLater(
        importTransfer(
          repo,
          createTransfer({'tr_dark': '1', 'tr_lang': 'ru'}, exportId: 'new'),
        ),
        throwsFormatException,
      );
      expect(repo.data, before);
    },
  );
  test('foreign fields in history and malformed key stats fail closed', () {
    expect(
      () => createTransfer({
        'tr_history': '[{"t":1,"wpm":2,"acc":99,"typedText":"private"}]',
      }, exportId: 'bad'),
      throwsFormatException,
    );
    expect(
      () => createTransfer({
        'tr_keystats': '{"a":{"ok":"not-number"}}',
      }, exportId: 'bad'),
      throwsFormatException,
    );
  });
  test(
    'concurrent session transactions are serialized and IDs idempotent',
    () async {
      final store = MemoryStore(), repo = LocalRepository(MemoryStore());
      final live = LocalRepository(store);
      await Future.wait(
        List.generate(15, (i) => live.appendSession({'id': 's-$i'})),
      );
      expect((live.data['sessions'] as List).length, 15);
      expect(await live.appendSession({'id': 's-1'}), false);
      final reload = LocalRepository(store);
      await reload.load();
      expect(reload.data, live.data);
      expect(repo.data['sessions'], isEmpty);
    },
  );
}

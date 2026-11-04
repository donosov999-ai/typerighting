import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/legacy_transfer.dart';
import 'package:typefree_flutter_foundation/data/progress_view.dart';
import 'package:typefree_flutter_foundation/data/key_statistics_store.dart';
import 'package:typefree_flutter_foundation/domain/adaptive.dart';
import 'package:typefree_flutter_foundation/data/webview_migration.dart';

import 'storage_transfer_test.dart' show MemoryStore;

/// Same-ID Tauri → Flutter update: the old WebView values pass the same
/// allowlist/validators/transaction as the I5 file import; foreign or broken
/// keys are skipped one by one, a repeat adds nothing, a conflict keeps
/// existing progress, and conflicts leave migration pending.
void main() {
  test('oversized combined stars and records do not make the repository unreadable', () async {
    final first = List.filled(510000, 'a').join();
    final second = List.filled(510000, 'b').join();
    for (final key in ['tr_compete', 'tr_kids', 'tr_course_ru']) {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      final current = key == 'tr_compete'
          ? jsonEncode({first: 42})
          : jsonEncode({
              'stars': {first: 2},
            });
      final incoming = key == 'tr_compete'
          ? jsonEncode({second: 80})
          : jsonEncode({
              'stars': {second: 3},
            });
      await repo.transaction((d) => (d['legacy'] as Map)[key] = current);
      await importWebviewValues(repo, {key: incoming});
      final reloaded = LocalRepository(store);
      await reloaded.load();
      expect(reloaded.data['legacy'][key], current);
      expect(
        ((reloaded.data['webviewPending'] as Map).values.single as Map)[key],
        incoming,
      );
      expect(needsWebviewMigration(reloaded.data), true);
    }
  });
  test(
    'key stats recover missing keys without adding overlapping observations',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      final current = '{"a":{"ok":7,"err":1}}';
      final older = '{"a":{"ok":20,"err":5},"b":{"ok":1,"err":9}}';
      await repo.transaction(
        (d) => (d['legacy'] as Map)['tr_keystats'] = current,
      );
      await importWebviewValues(repo, {'tr_keystats': older});
      final restarted = LocalRepository(store);
      await restarted.load();
      final stats = KeyStatisticsStore(restarted).currentStats;
      expect(stats['a'], {'ok': 7, 'err': 1});
      expect(stats['b'], {'ok': 1, 'err': 9});
      expect(
        weakLetters(stats, [
          {'id': 'a', 'ch': 'a'},
          {'id': 'b', 'ch': 'b'},
        ]).first,
        'b',
      );
      expect(
        ((restarted.data['webviewPending'] as Map).values.single
            as Map)['tr_keystats'],
        older,
      );
      await importWebviewValues(restarted, {'tr_keystats': older});
      expect(KeyStatisticsStore(restarted).currentStats, stats);
      expect(needsWebviewMigration(restarted.data), true);
    },
  );
  test(
    'conflicting practice progress preserves both sets and current position',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      final current =
          '{"bestWpm":65,"bestAcc":92,"done":["new","both"],"lastIdx":2}';
      final older =
          '{"bestWpm":50,"bestAcc":98,"done":["old","both"],"lastIdx":5}';
      await repo.transaction(
        (d) => (d['legacy'] as Map)['tr_progress_ruWords'] = current,
      );
      await importWebviewValues(repo, {'tr_progress_ruWords': older});
      final restarted = LocalRepository(store);
      await restarted.load();
      expect(jsonDecode(restarted.data['legacy']['tr_progress_ruWords']), {
        'bestWpm': 65,
        'bestAcc': 98,
        'done': ['new', 'both', 'old'],
        'lastIdx': 2,
      });
      expect(
        ((restarted.data['webviewPending'] as Map).values.single
            as Map)['tr_progress_ruWords'],
        older,
      );
      await importWebviewValues(restarted, {'tr_progress_ruWords': older});
      expect(
        jsonDecode(restarted.data['legacy']['tr_progress_ruWords'])['done'],
        ['new', 'both', 'old'],
      );
      expect(needsWebviewMigration(restarted.data), true);
    },
  );
  test('conflicting achievements and race records retain both sets across restart and retry', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    await repo.transaction((d) {
      (d['legacy'] as Map)['tr_ach'] = '["first","wpm30"]';
      (d['legacy'] as Map)['tr_compete'] = '{"words_en":80,"sprint_ru":40}';
    });
    final old = {
      'tr_ach': '["first","wpm60"]',
      'tr_compete': '{"words_en":50,"digits_ru":75}',
    };
    expect(
      (await importWebviewValues(repo, old)).result,
      WebviewMigrationResult.conflict,
    );
    final restarted = LocalRepository(store);
    await restarted.load();
    expect(ProgressView(restarted.data).achievements.toSet(), {
      'first',
      'wpm30',
      'wpm60',
    });
    expect(jsonDecode(restarted.data['legacy']['tr_compete']), {
      'words_en': 80,
      'sprint_ru': 40,
      'digits_ru': 75,
    });
    await importWebviewValues(restarted, old);
    expect(jsonDecode(restarted.data['legacy']['tr_compete']), {
      'words_en': 80,
      'sprint_ru': 40,
      'digits_ru': 75,
    });
    expect((restarted.data['webviewPending'] as Map).length, 1);
  });

  test('oversized combined achievement list stays unresolved and does not corrupt storage', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    final existing = [for (var i = 0; i < 600; i++) 'current_$i'];
    final incoming = [for (var i = 0; i < 600; i++) 'old_$i'];
    await repo.transaction(
      (d) => (d['legacy'] as Map)['tr_ach'] = jsonEncode(existing),
    );
    await importWebviewValues(repo, {'tr_ach': jsonEncode(incoming)});
    final restarted = LocalRepository(store);
    await restarted.load();
    expect(jsonDecode(restarted.data['legacy']['tr_ach']), existing);
    expect(
      ((restarted.data['webviewPending'] as Map).values.single
          as Map)['tr_ach'],
      jsonEncode(incoming),
    );
    expect(needsWebviewMigration(restarted.data), true);
  });
  test('conflicting child and course stars keep the best of both versions after restart', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    await repo.transaction((d) {
      (d['legacy'] as Map)['tr_kids'] = '{"stars":{"1":3,"2":1}}';
      (d['legacy'] as Map)['tr_course_ru'] = '{"stars":{"1":1,"5":3}}';
    });
    final source = {
      'tr_kids': '{"stars":{"1":1,"2":3,"3":2}}',
      'tr_course_ru': '{"stars":{"1":3,"2":2}}',
    };
    expect(
      (await importWebviewValues(repo, source)).result,
      WebviewMigrationResult.conflict,
    );
    final restarted = LocalRepository(store);
    await restarted.load();
    expect(jsonDecode(restarted.data['legacy']['tr_kids'])['stars'], {
      '1': 3,
      '2': 3,
      '3': 2,
    });
    expect(jsonDecode(restarted.data['legacy']['tr_course_ru'])['stars'], {
      '1': 3,
      '2': 2,
      '5': 3,
    });
    expect((restarted.data['webviewPending'] as Map).length, 1);
    expect(needsWebviewMigration(restarted.data), true);
    await importWebviewValues(restarted, source);
    expect(jsonDecode(restarted.data['legacy']['tr_kids'])['stars'], {
      '1': 3,
      '2': 3,
      '3': 2,
    });
    expect((restarted.data['webviewPending'] as Map).length, 1);
  });
  test(
    'failed star merge commits neither union nor pending snapshot',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      await repo.load();
      await repo.transaction(
        (d) => (d['legacy'] as Map)['tr_kids'] = '{"stars":{"1":1}}',
      );
      final before = repo.data;
      store.fail = true;
      await expectLater(
        importWebviewValues(repo, {'tr_kids': '{"stars":{"2":2}}'}),
        throwsStateError,
      );
      expect(repo.data, before);
      store.fail = false;
      final reloaded = LocalRepository(store);
      await reloaded.load();
      expect(reloaded.data, before);
      await importWebviewValues(reloaded, {'tr_kids': '{"stars":{"2":2}}'});
      expect(jsonDecode(reloaded.data['legacy']['tr_kids'])['stars'], {
        '1': 1,
        '2': 2,
      });
    },
  );
  test('old certificate name stays local, survives restart and never replaces a new name', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    await repo.transaction(
      (d) => (d['prefs'] as Map)['certificateName_m'] = 'New name',
    );
    await importWebviewValues(repo, {'tr_profile': 'm', 'tr_name': 'Old name'});
    final restarted = LocalRepository(store);
    await restarted.load();
    expect(restarted.data['prefs']['legacyCertificateName'], 'Old name');
    expect(restarted.data['prefs']['certificateName_m'], 'New name');
    expect((restarted.data['legacy'] as Map).containsKey('tr_name'), false);
    expect(needsWebviewMigration(restarted.data), false);
  });

  test('old certificate name fills only the known profile and conflicting names remain pending', () async {
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await importWebviewValues(repo, {'tr_profile': 'f', 'tr_name': 'Old name'});
    expect(repo.data['prefs']['certificateName_f'], 'Old name');
    expect(repo.data['prefs']['certificateName_m'], isNull);
    await repo.transaction(
      (d) => (d['prefs'] as Map).remove(webviewMigrationFlag),
    );
    final result = await importWebviewValues(repo, {
      'tr_profile': 'f',
      'tr_name': 'Different name',
    });
    expect(result.result, WebviewMigrationResult.conflict);
    expect(repo.data['prefs']['legacyCertificateName'], 'Old name');
    expect(repo.data['prefs']['certificateName_f'], 'Old name');
    expect(needsWebviewMigration(repo.data), true);
  });
  test('certificate name conflict stays pending across restart and empty reread', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    await importWebviewValues(repo, {'tr_profile': 'f', 'tr_name': 'Old name'});
    await repo.transaction((d) => (d['prefs'] as Map).remove(webviewMigrationFlag));
    expect((await importWebviewValues(repo, {'tr_name': 'Different name'})).result,
        WebviewMigrationResult.conflict);
    final reloaded = LocalRepository(store);
    await reloaded.load();
    expect((await importWebviewValues(reloaded, {})).result,
        WebviewMigrationResult.conflict);
    expect(needsWebviewMigration(reloaded.data), true);
    expect(reloaded.data['prefs']['legacyCertificateName'], 'Old name');
  });

  test('oversized certificate name stays pending after an empty reread', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    expect((await importWebviewValues(repo, {'tr_name': 'x' * 1000001})).result,
        WebviewMigrationResult.conflict);
    final reloaded = LocalRepository(store);
    await reloaded.load();
    expect((await importWebviewValues(reloaded, {})).result,
        WebviewMigrationResult.conflict);
    expect(needsWebviewMigration(reloaded.data), true);
  });
  test('malformed WebView messages never become a successful empty read', () {
    expect(decodeWebviewMigrationMessage('{'), isNull);
    expect(decodeWebviewMigrationMessage('{"ok":false,"values":{}}'), isNull);
    expect(
      decodeWebviewMigrationMessage('{"ok":true,"values":{"tr_history":12}}'),
      isNull,
    );
    expect(
      decodeWebviewMigrationMessage(
        '{"ok":true,"values":{"tr_lang":"ru","tr_history":null}}',
      ),
      isNull,
    );
    expect(decodeWebviewMigrationMessage('{"ok":true,"values":{}}'), isEmpty);
    expect(
      decodeWebviewMigrationMessage('{"ok":true,"values":{"tr_lang":"ru"}}'),
      {'tr_lang': 'ru'},
    );
  });
  final old = <String, String>{
    'tr_history': jsonEncode([
      {'t': 1700000000000, 'wpm': 41, 'acc': 97, 'len': 45},
    ]),
    'tr_profile': 'm',
    'tr_lang': 'ru',
    'tr_dark': '1',
    'tr_account_pin': '1234', // never migrated: not on the allowlist
    'tr_layout': 'dvorak', // invalid value: skipped alone
  };

  Future<LocalRepository> fresh() async {
    final r = LocalRepository(MemoryStore());
    await r.load();
    return r;
  }

  test('empty old storage: nothing, flag set', () async {
    final r = await fresh();
    expect(needsWebviewMigration(r.data), true);
    final o = await importWebviewValues(r, {});
    expect(o.result, WebviewMigrationResult.nothing);
    expect(needsWebviewMigration(r.data), false);
  });

  test(
    'an empty or changed later read does not clear a saved conflict',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      await importTransfer(
        repo,
        createTransfer({'tr_lang': 'en'}, exportId: 'existing'),
      );
      expect(
        (await importWebviewValues(repo, {'tr_lang': 'ru'})).result,
        WebviewMigrationResult.conflict,
      );
      final reloaded = LocalRepository(store);
      await reloaded.load();
      expect(
        (await importWebviewValues(reloaded, {})).result,
        WebviewMigrationResult.conflict,
      );
      expect(needsWebviewMigration(reloaded.data), isTrue);
      expect(
        (await importWebviewValues(reloaded, {'tr_lang': 'en'})).result,
        WebviewMigrationResult.conflict,
      );
      final again = LocalRepository(store);
      await again.load();
      expect(needsWebviewMigration(again.data), isTrue);
      expect((again.data['webviewPending'] as Map).isNotEmpty, isTrue);
      expect((again.data['legacy'] as Map)['tr_lang'], 'en');
    },
  );

  test(
    'invalid history leaves retry enabled while foreign-only data can finish',
    () async {
      final invalid = await fresh();
      expect(
        (await importWebviewValues(invalid, {'tr_history': '{broken'})).result,
        WebviewMigrationResult.conflict,
      );
      expect(needsWebviewMigration(invalid.data), true);
      expect(invalid.data['prefs']['webviewInvalidKeys'], ['tr_history']);
      expect(jsonEncode(invalid.data).contains('{broken'), false);
      await importWebviewValues(invalid, {});
      expect(invalid.data['prefs']['webviewInvalidKeys'], ['tr_history']);
      expect(needsWebviewMigration(invalid.data), true);
      await importWebviewValues(invalid, {'tr_history': '[]'});
      expect(
        (invalid.data['prefs'] as Map).containsKey('webviewInvalidKeys'),
        false,
      );
      expect(needsWebviewMigration(invalid.data), false);
      final foreign = await fresh();
      expect(
        (await importWebviewValues(foreign, {
          'tr_account_pin': 'private',
        })).result,
        WebviewMigrationResult.nothing,
      );
      expect(needsWebviewMigration(foreign.data), false);
    },
  );

  test('imports valid values but leaves invalid known value pending', () async {
    final r = await fresh();
    final o = await importWebviewValues(r, old);
    expect(o.result, WebviewMigrationResult.conflict);
    expect(o.kept, 4);
    expect(o.skipped, 2);
    final legacy = r.data['legacy'] as Map;
    expect(legacy['tr_lang'], 'ru');
    expect(legacy.containsKey('tr_account_pin'), false);
    expect(legacy.containsKey('tr_layout'), false);
    expect((r.data['prefs'] as Map)['profile'], 'm', reason: 'welcome skipped');
    expect(needsWebviewMigration(r.data), true);
  });

  test('repeat read adds nothing', () async {
    final r = await fresh();
    await importWebviewValues(r, old);
    final before = r.data;
    final o = await importWebviewValues(r, old);
    expect(o.result, WebviewMigrationResult.conflict);
    expect(r.data['legacy'], before['legacy']);
  });

  test('conflict keeps existing progress', () async {
    final r = await fresh();
    await importWebviewValues(r, {'tr_lang': 'en'});
    await r.transaction(
      (d) => (d['prefs'] as Map).remove(webviewMigrationFlag),
    );
    final o = await importWebviewValues(r, {'tr_lang': 'ru'});
    expect(o.result, WebviewMigrationResult.conflict);
    expect((r.data['legacy'] as Map)['tr_lang'], 'en');
    expect(needsWebviewMigration(r.data), true);
  });

  test('conflicting preference preserves both existing choice and unrelated history', () async {
    final r = await fresh();
    await importWebviewValues(r, {'tr_lang': 'en'});
    await r.transaction(
      (d) => (d['prefs'] as Map).remove(webviewMigrationFlag),
    );
    final o = await importWebviewValues(r, {
      'tr_lang': 'ru',
      'tr_history': old['tr_history']!,
    });
    expect(o.result, WebviewMigrationResult.conflict);
    expect((r.data['legacy'] as Map)['tr_lang'], 'en');
    expect((r.data['legacy'] as Map)['tr_history'], old['tr_history']);
    expect(needsWebviewMigration(r.data), true);
    final again = await importWebviewValues(r, {
      'tr_lang': 'ru',
      'tr_history': old['tr_history']!,
    });
    expect(again.result, WebviewMigrationResult.conflict);
    expect((r.data['legacy'] as Map)['tr_history'], old['tr_history']);
  });

  test('history recovered alongside a conflict survives restart without duplication', () async {
    final store = MemoryStore();
    final first = LocalRepository(store);
    await first.load();
    await importWebviewValues(first, {'tr_lang': 'en'});
    await first.transaction(
      (d) => (d['prefs'] as Map).remove(webviewMigrationFlag),
    );
    final source = {'tr_lang': 'ru', 'tr_history': old['tr_history']!};
    expect(
      (await importWebviewValues(first, source)).result,
      WebviewMigrationResult.conflict,
    );

    final restarted = LocalRepository(store);
    await restarted.load();
    expect(needsWebviewMigration(restarted.data), true);
    expect(ProgressView(restarted.data).timeline, hasLength(1));
    expect(
      (await importWebviewValues(restarted, source)).result,
      WebviewMigrationResult.conflict,
    );
    expect(ProgressView(restarted.data).timeline, hasLength(1));
    expect((restarted.data['legacy'] as Map)['tr_lang'], 'en');
  });

  test('failed write during partial recovery leaves all data and retry state intact', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    await importWebviewValues(repo, {'tr_lang': 'en'});
    await repo.transaction(
      (d) => (d['prefs'] as Map).remove(webviewMigrationFlag),
    );
    final before = repo.data;
    final source = {'tr_lang': 'ru', 'tr_history': old['tr_history']!};
    store.fail = true;
    await expectLater(importWebviewValues(repo, source), throwsStateError);
    expect(repo.data, before);
    final reloaded = LocalRepository(store);
    await reloaded.load();
    expect(reloaded.data, before);
    store.fail = false;
    expect(
      (await importWebviewValues(reloaded, source)).result,
      WebviewMigrationResult.conflict,
    );
    expect(ProgressView(reloaded.data).timeline, hasLength(1));
    expect(needsWebviewMigration(reloaded.data), true);
  });
  test(
    'conflicting histories retain both timelines across restart and retry',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      await repo.load();
      final currentHistory = jsonEncode([
        {'t': 1700000001000, 'wpm': 60, 'acc': 99, 'len': 50},
      ]);
      await repo.transaction(
        (d) => (d['legacy'] as Map)['tr_history'] = currentHistory,
      );
      expect(
        (await importWebviewValues(repo, {
          'tr_history': old['tr_history']!,
        })).result,
        WebviewMigrationResult.conflict,
      );
      expect((repo.data['legacy'] as Map)['tr_history'], currentHistory);
      expect(
        (repo.data['legacyArchive'] as Map)['tr_history'],
        old['tr_history'],
      );
      expect(ProgressView(repo.data).timeline, hasLength(2));
      final reloaded = LocalRepository(store);
      await reloaded.load();
      await importWebviewValues(reloaded, {'tr_history': old['tr_history']!});
      expect(ProgressView(reloaded.data).timeline, hasLength(2));
      expect(needsWebviewMigration(reloaded.data), true);
    },
  );

  test('conflicting history never overwrites an existing archive', () async {
    final store = MemoryStore();
    final repo = LocalRepository(store);
    await repo.load();
    await repo.transaction((d) {
      (d['legacy'] as Map)['tr_history'] = '[]';
      (d['legacyArchive'] as Map)['tr_history'] = '[]';
    });
    expect(
      (await importWebviewValues(repo, {
        'tr_history': old['tr_history']!,
      })).result,
      WebviewMigrationResult.conflict,
    );
    expect((repo.data['legacyArchive'] as Map)['tr_history'], '[]');
    expect(needsWebviewMigration(repo.data), true);
    final pending = repo.data['webviewPending'] as Map;
    expect(pending.length, 1);
    expect((pending.values.single as Map)['tr_history'], old['tr_history']);
    final reloaded = LocalRepository(store);
    await reloaded.load();
    await importWebviewValues(reloaded, {'tr_history': old['tr_history']!});
    expect((reloaded.data['webviewPending'] as Map).length, 1);
    expect((reloaded.data['legacyArchive'] as Map)['tr_history'], '[]');
  });

  test(
    'pending snapshots retain changed source versions without secret keys',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      await repo.load();
      await repo.transaction((d) => (d['legacy'] as Map)['tr_lang'] = 'en');
      await importWebviewValues(repo, {
        'tr_lang': 'ru',
        'tr_account_pin': '1234',
      });
      await importWebviewValues(repo, {
        'tr_lang': 'fr',
        'tr_account_pin': '1234',
      });
      final reloaded = LocalRepository(store);
      await reloaded.load();
      final pending = reloaded.data['webviewPending'] as Map;
      expect(pending.length, 2);
      expect(
        pending.values.map((v) => (v as Map)['tr_lang']),
        containsAll(['ru', 'fr']),
      );
      expect(
        pending.values.every((v) => !(v as Map).containsKey('tr_account_pin')),
        true,
      );
    },
  );
  test(
    'corrupted recovery data is rejected without overwriting the source file',
    () async {
      final store = MemoryStore();
      final repo = LocalRepository(store);
      await repo.load();
      await repo.transaction((d) => (d['legacy'] as Map)['tr_lang'] = 'en');
      await importWebviewValues(repo, {'tr_lang': 'ru'});
      final corrupt = jsonDecode(store.values[candidateDataKey]!) as Map;
      final pending = corrupt['webviewPending'] as Map;
      (pending.values.single as Map)['tr_lang'] = 'fr';
      final raw = jsonEncode(corrupt);
      store.values[candidateDataKey] = raw;
      final reload = LocalRepository(store);
      await expectLater(reload.load(), throwsFormatException);
      expect(store.values[candidateDataKey], raw);
    },
  );
}

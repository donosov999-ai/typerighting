import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/webview_migration.dart';

import 'storage_transfer_test.dart' show MemoryStore;

/// Same-ID Tauri → Flutter update: the old WebView values pass the same
/// allowlist/validators/transaction as the I5 file import; foreign or broken
/// keys are skipped one by one, a repeat adds nothing, a conflict keeps
/// existing progress, and the one-time flag is set after every finished read.
void main() {
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

  test('imports allowed values, skips foreign and invalid ones', () async {
    final r = await fresh();
    final o = await importWebviewValues(r, old);
    expect(o.result, WebviewMigrationResult.imported);
    expect(o.kept, 4);
    expect(o.skipped, 2);
    final legacy = r.data['legacy'] as Map;
    expect(legacy['tr_lang'], 'ru');
    expect(legacy.containsKey('tr_account_pin'), false);
    expect(legacy.containsKey('tr_layout'), false);
    expect((r.data['prefs'] as Map)['profile'], 'm', reason: 'welcome skipped');
    expect(needsWebviewMigration(r.data), false);
  });

  test('repeat read adds nothing', () async {
    final r = await fresh();
    await importWebviewValues(r, old);
    final before = r.data;
    final o = await importWebviewValues(r, old);
    expect(o.result, WebviewMigrationResult.alreadyImported);
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
    expect(needsWebviewMigration(r.data), false);
  });
}

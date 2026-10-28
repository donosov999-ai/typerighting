import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/legacy_transfer.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/string_store.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/transfer_page.dart';
import 'package:typefree_flutter_foundation/main.dart';

class _Store implements StringStore {
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

class _Memory implements AppearanceStore {
  @override
  Future<void> save(Map<String, Object> value) async {}
}

/// I5: the file is verified before anything is written; an interrupted write
/// commits nothing and «Повторить импорт» finishes it; a corrupted file and a
/// conflict keep existing progress; a second import adds nothing.
void main() {
  final file = createTransfer({
    'tr_history': jsonEncode([
      {'t': 1700000000000, 'wpm': 42, 'acc': 97, 'len': 45},
    ]),
    'tr_lang': 'ru',
  }, exportId: 'page-1');

  testWidgets('I5: verify, interrupted write, retry, done, repeat', (
    tester,
  ) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final theme = AppearanceController(
      resources.registry,
      _Memory(),
      existingInstall: true,
    ).theme(Brightness.dark);
    final store = _Store();
    final repo = LocalRepository(store);
    await tester.runAsync(repo.load);
    Map<String, dynamic>? next;
    Future<void> show() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransferPage(
                key: UniqueKey(),
                language: 'ru',
                repository: repo,
                pick: () async => next,
              ),
            ),
          ),
        ),
      );
    }

    String c(String k) => transferCopy('ru', k);

    // Corrupted file: nothing written, honest message.
    await show();
    next = jsonDecode(jsonEncode(file)) as Map<String, dynamic>;
    (next!['values'] as Map)['tr_lang'] = 'en';
    await tester.tap(find.byKey(const ValueKey('transfer-choose')));
    await tester.pumpAndSettle();
    expect(find.text(c('bad')), findsOneWidget);
    expect(store.values, isEmpty);

    // Disk fails mid-import: verified, interrupted, nothing committed.
    await show();
    next = file;
    store.fail = true;
    await tester.tap(find.byKey(const ValueKey('transfer-choose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transfer-checked')), findsOneWidget);
    expect(find.text(c('interrupted')), findsOneWidget);
    expect(store.values, isEmpty);

    // Retry after the disk recovers: done, values in the repository.
    store.fail = false;
    await tester.tap(find.byKey(const ValueKey('transfer-retry')));
    await tester.pumpAndSettle();
    expect(find.text(c('done.d')), findsOneWidget);
    expect((repo.data['legacy'] as Map)['tr_lang'], 'ru');

    // Same file again: nothing added twice.
    await show();
    await tester.tap(find.byKey(const ValueKey('transfer-choose')));
    await tester.pumpAndSettle();
    expect(find.text(c('again')), findsOneWidget);

    // Different progress for the same entry: conflict, existing kept.
    await show();
    next = createTransfer({'tr_lang': 'en'}, exportId: 'page-2');
    await tester.tap(find.byKey(const ValueKey('transfer-choose')));
    await tester.pumpAndSettle();
    expect(find.text(c('conflict')), findsOneWidget);
    expect(find.byKey(const ValueKey('transfer-retry')), findsNothing);
    expect((repo.data['legacy'] as Map)['tr_lang'], 'ru');
    expect(tester.takeException(), isNull);
  });

  test('I5 count: Russian plural forms, English singular', () {
    expect(transferCount(1, 'ru'), '1 запись');
    expect(transferCount(2, 'ru'), '2 записи');
    expect(transferCount(5, 'ru'), '5 записей');
    expect(transferCount(12, 'ru'), '12 записей');
    expect(transferCount(21, 'ru'), '21 запись');
    expect(transferCount(1, 'en'), '1 entry');
    expect(transferCount(3, 'en'), '3 entries');
  });

  testWidgets('I5 copy exists in all seven languages', (tester) async {
    for (final l in ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt']) {
      for (final k in [
        'title',
        'short',
        'entry',
        'retry',
        'safe',
        'conflict',
      ]) {
        expect(transferCopy(l, k), isNot(k), reason: '$l/$k');
      }
    }
  });
}

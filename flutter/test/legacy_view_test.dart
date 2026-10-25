import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/file_store.dart';
import 'package:typefree_flutter_foundation/data/legacy_transfer.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/progress_view.dart';

import 'storage_transfer_test.dart' show MemoryStore;

void main() {
  final raw = <String, String>{
    'tr_history': jsonEncode([
      {'t': 1, 'wpm': 42, 'acc': .97},
      {'t': 1, 'wpm': 42, 'acc': .97},
    ]),
    'tr_profile': 'f',
    'tr_lang': 'ru',
    'tr_block': '1',
    'tr_keyb': '0',
    'typefree_practice_bank': 'abandon',
    'typefree_practice_text_bank': 'engRus',
    'tr_progress_abandon': jsonEncode({
      'bestWpm': 42,
      'bestAcc': 97,
      'done': ['old-1'],
      'lastIdx': 1,
    }),
    'tr_course_ru': '{"stars":{"1":3,"2":2}}',
    'tr_kids': '{"stars":{"1":2}}',
    'tr_ach': '["first"]',
  };
  test('import adapts preferences, archives hidden lessons, preserves duplicate old rows without invented metadata', () async {
    final repo = LocalRepository(MemoryStore());
    await importTransfer(repo, createTransfer(raw, exportId: 'fixture'));
    final prefs = repo.data['prefs'] as Map;
    expect(prefs['bank'], 'ruWords');
    expect(prefs['textBank'], 'ruWords');
    expect(prefs['block'], true);
    expect(prefs['keyboard'], false);
    expect(prefs['profile'], 'f');
    final view = ProgressView(repo.data);
    expect(view.previousSessions.length, 2);
    expect(view.previousSessions.first['accuracy'], 97);
    expect(view.previousSessions.first.containsKey('profile'), false);
    expect(view.previousSessions.first.containsKey('language'), false);
    expect(view.previousSessions.first.containsKey('difficulty'), false);
    expect(view.courseStars, 5);
    expect(view.kidsStars, 2);
    expect(view.achievements, ['first']);
    expect(view.banks['abandon']['done'], ['old-1']);
  });
  test('new history does not duplicate the legacy mirror or truncate imported archive; replay is inert', () async {
    final repo = LocalRepository(MemoryStore());
    final envelope = createTransfer(raw, exportId: 'fixture');
    await importTransfer(repo, envelope);
    await repo.transaction((doc) {
      (doc['sessions'] as List).add({
        'id': 'new',
        't': 2,
        'wpm': 50,
        'accuracy': 98,
      });
      (doc['legacy'] as Map)['tr_history'] = '[{"t":2,"wpm":50,"acc":98}]';
    });
    expect(await importTransfer(repo, envelope), false);
    final view = ProgressView(repo.data);
    expect(view.timeline.length, 3);
    expect(view.timeline.first['origin'], 'flutter');
    expect(view.previousSessions.length, 2);
    expect(
      (repo.data['legacyArchive'] as Map)['tr_history'],
      raw['tr_history'],
    );
  });
  test(
    'an existing candidate preference wins over transfer defaults',
    () async {
      final repo = LocalRepository(MemoryStore());
      await repo.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
          'profile': 'm',
          'keyboard': true,
          'bank': 'classic',
          'index': 4,
        });
      });
      await importTransfer(repo, createTransfer(raw, exportId: 'fixture'));
      final p = repo.data['prefs'] as Map;
      expect(p['profile'], 'm');
      expect(p['keyboard'], true);
      expect(p['bank'], 'classic');
      expect(p['index'], 4);
    },
  );
  test('candidate custom-text progress remains readable without allowing custom content in transfers', () async {
    final store = MemoryStore(), repo = LocalRepository(MemoryStore());
    final live = LocalRepository(store);
    await live.transaction((d) {
      (d['legacy'] as Map)['tr_progress_custom'] =
          '{"bestWpm":20,"bestAcc":90,"lastIdx":0,"done":["custom"]}';
    });
    final again = LocalRepository(store);
    await again.load();
    expect(ProgressView(again.data).banks['custom']['bestWpm'], 20);
    expect(
      (createTransfer({
                'tr_progress_custom':
                    '{"bestWpm":20,"bestAcc":90,"lastIdx":0,"done":["custom"]}',
              }, exportId: 'filter')['values']
              as Map)
          .isEmpty,
      true,
    );
    expect(repo.data['legacy'], isEmpty);
    expect(
      () => createTransfer({
        'tr_progress_ruWords':
            '{"bestWpm":20,"bestAcc":90,"lastIdx":0.5,"done":[]}',
      }, exportId: 'fractional-index'),
      throwsFormatException,
    );
  });
  test('corrupt persisted archive or settings fail closed without modifying source', () async {
    for (final corrupt in [
      <String, dynamic>{
        'legacyArchive': {'tr_history': '[{"t":1,"wpm":2,"acc":101}]'},
      },
      <String, dynamic>{
        'prefs': {'bank': 'abandon'},
      },
      <String, dynamic>{
        'prefs': {'index': -2},
      },
      <String, dynamic>{
        'legacy': {'tr_acc': 'forbidden'},
      },
      <String, dynamic>{
        'receipts': {'bad': 'not-a-digest'},
      },
    ]) {
      final store = MemoryStore();
      final doc = LocalRepository(store).data..addAll(corrupt);
      final encoded = jsonEncode(doc);
      store.values[candidateDataKey] = encoded;
      await expectLater(LocalRepository(store).load(), throwsFormatException);
      expect(store.values[candidateDataKey], encoded);
    }
  });
  test('real file store survives interrupted pending write, preserves primary on error and supports retry', () async {
    final dir = await Directory.systemTemp.createTemp('typefree-fixture-');
    addTearDown(() => dir.delete(recursive: true));
    final store = NativeStore(dir), repo = LocalRepository(NativeStore(dir));
    final envelope = createTransfer(raw, exportId: 'native-fixture');
    await importTransfer(repo, envelope);
    final before = await store.file(candidateDataKey).readAsString();
    final pending = File('${store.file(candidateDataKey).path}.pending');
    await pending.writeAsString('{interrupted');
    final restarted = LocalRepository(store);
    await restarted.load();
    expect(ProgressView(restarted.data).previousSessions.length, 2);
    await pending.delete();
    await Directory(pending.path).create();
    await expectLater(
      restarted.transaction((d) {
        (d['prefs'] as Map)['retry'] = true;
      }),
      throwsA(isA<FileSystemException>()),
    );
    expect(await store.file(candidateDataKey).readAsString(), before);
    expect((restarted.data['prefs'] as Map).containsKey('retry'), false);
    await Directory(pending.path).delete();
    await restarted.transaction((d) {
      (d['prefs'] as Map)['retry'] = true;
    });
    final again = LocalRepository(store);
    await again.load();
    expect((again.data['prefs'] as Map)['retry'], true);
    expect(await importTransfer(again, envelope), false);
  });
}

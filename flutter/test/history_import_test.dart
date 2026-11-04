import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/artifact_export.dart';
import 'package:typefree_flutter_foundation/data/history_import.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/progress_view.dart';
import 'package:typefree_flutter_foundation/features/progress_page.dart';

import 'storage_transfer_test.dart' show MemoryStore;

void main() {
  final session = <String, dynamic>{
    'id': 'session-1',
    'title': 'Practice',
    'exercise': 'a',
    'language': 'ru',
    'profile': 'm',
    'mode': 'practice',
    'difficulty': '1',
    't': 1700000000000,
    'wpm': 42,
    'accuracy': 97,
    'errors': 1,
    'elapsedMs': 2000,
    'len': 40,
  };
  Future<LocalRepository> fresh([MemoryStore? store]) async {
    final repo = LocalRepository(store ?? MemoryStore());
    await repo.load();
    return repo;
  }

  test(
    'export, import and retry retain new sessions and separate old copies',
    () async {
      final source = await fresh();
      await source.appendSession(session);
      await source.transaction((doc) {
        (doc['legacyArchive'] as Map)['tr_history'] =
            '[{"t":1,"wpm":20,"acc":90}]';
      });
      Map<String, dynamic>? file;
      await exportHistory(source, (name, bytes, mime) async {
        file = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        return ArtifactExportOutcome.saved;
      }, 1);
      final parsed = await HistoryImport.verify(file!);
      final store = MemoryStore();
      final target = await fresh(store);
      expect(await parsed.apply(target), true);
      expect((target.data['sessions'] as List).single, session);
      expect(ProgressView(target.data).legacyTimeline.length, 1);
      expect((target.data['webviewPending'] as Map), isEmpty);
      final restarted = await fresh(store);
      expect(await parsed.apply(restarted), false);
      expect((restarted.data['sessions'] as List).length, 1);
      expect(ProgressView(restarted.data).legacyTimeline.length, 1);
      expect((restarted.data['webviewPending'] as Map), isEmpty);
    },
  );

  test(
    'existing history keeps incoming old rows separate and unchanged',
    () async {
      final target = await fresh();
      await target.transaction((doc) {
        (doc['legacyArchive'] as Map)['tr_history'] =
            '[{"t":2,"wpm":30,"acc":90}]';
      });
      final parsed = await HistoryImport.verify({
        'schema': 'typefree.history/1',
        'exportedAt': 1,
        'sessions': [
          {'origin': 'legacy', 't': 1, 'wpm': 20, 'acc': 90},
        ],
      });
      expect(await parsed.apply(target), isTrue);
      expect(ProgressView(target.data).legacyTimeline.single['t'], 2);
      expect((target.data['webviewPending'] as Map).length, 1);
      expect(await parsed.apply(target), isFalse);
    },
  );

  test(
    'different row with same ID and corrupt copies never change existing data',
    () async {
      final repo = await fresh();
      await repo.appendSession(session);
      final incoming = {...session, 'wpm': 77, 'origin': 'flutter'};
      final file = {
        'schema': 'typefree.history/1',
        'exportedAt': 1,
        'sessions': [incoming],
      };
      final parsed = await HistoryImport.verify(file);
      final before = repo.data;
      await expectLater(parsed.apply(repo), throwsFormatException);
      expect(repo.data, before);
      file['unresolvedHistoryCopies'] = [
        [
          {'t': 1, 'wpm': -1, 'acc': 90},
        ],
      ];
      await expectLater(HistoryImport.verify(file), throwsFormatException);
      expect(repo.data, before);
    },
  );
  test(
    'unknown old history fields are rejected instead of discarded',
    () async {
      final repo = await fresh();
      final before = repo.data;
      await expectLater(
        HistoryImport.verify({
          'schema': 'typefree.history/1',
          'exportedAt': 1,
          'sessions': [
            {
              'origin': 'legacy',
              't': 1,
              'wpm': 20,
              'acc': 90,
              'futureMetric': 42,
            },
          ],
        }),
        throwsFormatException,
      );
      expect(repo.data, before);
    },
  );
  test(
    'failed history write leaves existing state unchanged and retry succeeds',
    () async {
      final store = MemoryStore();
      final target = await fresh(store);
      final parsed = await HistoryImport.verify({
        'schema': 'typefree.history/1',
        'exportedAt': 1,
        'sessions': [
          {...session, 'origin': 'flutter'},
        ],
        'unresolvedHistoryCopies': [
          [
            {'t': 1, 'wpm': 20, 'acc': 90},
          ],
        ],
      });
      final before = target.data;
      store.fail = true;
      await expectLater(parsed.apply(target), throwsStateError);
      expect(target.data, before);
      store.fail = false;
      final restarted = await fresh(store);
      expect(restarted.data, before);
      expect(await parsed.apply(restarted), true);
      expect((restarted.data['sessions'] as List).single, session);
      expect((restarted.data['webviewPending'] as Map).length, 1);
    },
  );
}

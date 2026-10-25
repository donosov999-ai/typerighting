import 'dart:convert';
import 'dart:io';

import 'package:typefree_flutter_foundation/data/file_store.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/legacy_transfer.dart';
import 'package:typefree_flutter_foundation/data/progress_view.dart';

/// Test harness, not an automatic installed-app migration entry point.
Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('fixture-run directory required');
  final directory = Directory(args.single).absolute;
  final marker = File('${directory.path}/fixture-run.json');
  final manifest = jsonDecode(await marker.readAsString()) as Map;
  if (manifest['scope'] !=
      'synthetic named WKWebsiteDataStore only; no installed app storage') {
    throw StateError('Not a disposable fixture manifest');
  }
  final source = File('${directory.path}/read.json');
  final before = await source.readAsString();
  final raw = Map<String, String>.from(jsonDecode(before) as Map);
  final envelope = createTransfer(
    raw,
    exportId: 'webkit-${manifest['fixtureId']}',
  );
  final store = NativeStore(Directory('${directory.path}/candidate'));
  final repo = LocalRepository(store);
  await repo.load();
  final inserted = await importTransfer(repo, envelope);
  final reload = LocalRepository(store);
  await reload.load();
  final replay = await importTransfer(reload, envelope);
  final view = ProgressView(reload.data);
  if (replay ||
      view.previousSessions.length != 1 ||
      view.courseStars != 3 ||
      view.kidsStars != 2 ||
      view.previousSessions.single['wpm'] != 42 ||
      (reload.data['legacy'] as Map).containsKey('tr_acc') ||
      before != await source.readAsString()) {
    throw StateError('Fixture preservation failed');
  }
  final report = {
    'scope': manifest['scope'],
    'fixtureId': manifest['fixtureId'],
    'webkitKeys': raw.length,
    'allowedImportedKeys': (envelope['values'] as Map).length,
    'firstImportInserted': inserted,
    'replayInserted': replay,
    'historyRows': view.previousSessions.length,
    'courseStars': view.courseStars,
    'kidsStars': view.kidsStars,
    'sourceUnchanged': true,
    'candidateReload': 'PASS',
    'pinDeviceQueueExcluded': true,
    'installedAppUpdateProven': false,
  };
  await File('${directory.path}/report.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(jsonEncode(report));
}

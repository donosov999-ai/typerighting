import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/content_selection.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// The author's release selection (editor format typefree-content-selection
/// v1, group ids `app:<lang>:<bank>`) against the real practice catalog:
/// excluded entries and switched-off banks disappear, IDs of what stays are
/// unchanged, anything that does not fit keeps the full catalog.
void main() {
  final catalog = jsonDecode(
    File('assets/baseline/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  List<Map> items(Map<String, dynamic> c, String lang) =>
      ((c['catalog'] as Map)[lang] as List).cast<Map>();
  Map<String, dynamic> manifest(Map<String, Object> groups) => {
    'format': 'typefree-content-selection',
    'version': 1,
    'snapshot': 'test',
    'groups': groups,
  };

  test('no manifest or empty groups: catalog unchanged', () {
    expect(applyContentSelection(catalog, null).catalog, same(catalog));
    final r = applyContentSelection(catalog, manifest({}));
    expect(r.applied, true);
    expect(jsonEncode(r.catalog), jsonEncode(catalog));
  });

  test('shipped asset is a valid no-op selection', () {
    final shipped = jsonDecode(
      File('assets/content/release-selection.json').readAsStringSync(),
    );
    final r = applyContentSelection(catalog, shipped);
    expect(r.applied, true);
    expect(jsonEncode(r.catalog), jsonEncode(catalog));
  });

  test('excluded entries go, the rest keep their IDs and order', () {
    final r = applyContentSelection(
      catalog,
      manifest({
        'app:ru:ruWords': {
          'enabled': true,
          'excluded': ['ruw-2'],
        },
      }),
    );
    expect(r.applied, true);
    final before = items(catalog, 'ru').map((i) => i['id']).toList();
    final after = items(r.catalog, 'ru').map((i) => i['id']).toList();
    expect(after, before.where((id) => id != 'ruw-2').toList());
    expect(items(r.catalog, 'en').length, items(catalog, 'en').length);
  });

  test('a switched-off bank goes; the saved bank falls back', () {
    final r = applyContentSelection(
      catalog,
      manifest({
        'app:ru:ruWords': {'enabled': false, 'excluded': []},
      }),
    );
    expect(items(r.catalog, 'ru').any((i) => i['bank'] == 'ruWords'), false);
    expect(availableBank(r.catalog, 'ru', 'ruWords'), isNot('ruWords'));
    expect(availableBank(r.catalog, 'ru', 'ruPhrases'), 'ruPhrases');
    expect(availableBank(r.catalog, 'en', 'classic'), 'classic');
  });

  test('app:all:digits covers every language', () {
    final r = applyContentSelection(
      catalog,
      manifest({
        'app:all:digits': {
          'enabled': true,
          'excluded': ['digits-1'],
        },
      }),
    );
    for (final lang in (catalog['catalog'] as Map).keys) {
      expect(
        items(r.catalog, lang as String).any((i) => i['id'] == 'digits-1'),
        false,
      );
    }
  });

  test('locked Shestov groups cannot be enabled', () {
    final r = applyContentSelection(
      catalog,
      manifest({
        'app:en:abandon': {'enabled': true, 'excluded': []},
      }),
    );
    expect(r.applied, false);
    expect(r.catalog, same(catalog));
  });

  test('locked banks stay hidden even with missing or invalid selection', () {
    final source = jsonDecode(jsonEncode(catalog)) as Map<String, dynamic>;
    final rows = (source['catalog'] as Map)['en'] as List;
    for (final bank in ['abandon', 'engRus', 'letterByLetter']) {
      rows.add({
        'id': 'locked-$bank',
        'bank': bank,
        'lines': ['private lesson'],
      });
    }
    for (final selection in [
      null,
      {'format': 'invalid'},
      manifest({}),
    ]) {
      final result = applyContentSelection(source, selection);
      final banks = items(result.catalog, 'en').map((item) => item['bank']);
      expect(banks, isNot(contains('abandon')));
      expect(banks, isNot(contains('engRus')));
      expect(banks, isNot(contains('letterByLetter')));
      expect(banks, contains('classic'));
    }
    expect(
      rows
          .where((row) => (row as Map)['id'].toString().startsWith('locked-'))
          .length,
      3,
      reason: 'The input catalog must not be modified',
    );
  });

  test('course/kids/competition groups are reported, not applied', () {
    final r = applyContentSelection(
      catalog,
      manifest({
        'course:ru:lessons': {'enabled': false, 'excluded': []},
      }),
    );
    expect(r.applied, true);
    expect(r.notes.single, startsWith('not applied'));
    expect(jsonEncode(r.catalog), jsonEncode(catalog));
  });

  test('anything that does not fit keeps the full catalog', () {
    for (final bad in [
      {'format': 'other', 'version': 1, 'groups': {}},
      {'format': 'typefree-content-selection', 'version': 2, 'groups': {}},
      manifest({
        'app:ru:ruWords': {
          'enabled': true,
          'excluded': ['no-such-id'],
        },
      }),
      manifest({
        'app:xx:classic': {'enabled': true, 'excluded': []},
      }),
      manifest({
        'app:ru:ruWords': {'enabled': 'yes', 'excluded': []},
      }),
      // Every bank of a language off: no practice left.
      manifest({
        for (final b in ['classic', 'poemHymn'])
          'app:en:$b': {'enabled': false, 'excluded': []},
        'app:all:digits': {'enabled': false, 'excluded': []},
      }),
    ]) {
      final r = applyContentSelection(catalog, bad);
      expect(r.applied, false, reason: jsonEncode(bad));
      expect(r.catalog, same(catalog));
    }
  });

  test('real editor export (releaseSelection, content list dropped)', () {
    final exported = jsonDecode(
      File('test/fixtures/editor-release-selection.json').readAsStringSync(),
    );
    final r = applyContentSelection(catalog, exported);
    expect(r.applied, true, reason: r.notes.join('; '));
    final ru = items(r.catalog, 'ru').map((i) => i['id']).toSet();
    expect(ru.contains('ruw-2'), false);
    expect(ru.contains('ruw-1'), true);
    expect(items(r.catalog, 'ru').any((i) => i['bank'] == 'poemHymn'), false);
    expect(items(r.catalog, 'en').any((i) => i['bank'] == 'poemHymn'), true);
    expect(ru.contains('digits-1'), false);
    expect(ru.contains('digits-2'), true);
    // Course and web groups are the editor's, not this catalog's.
    expect(r.notes.length, 2);
  });

  testWidgets('saved bank switched off by the author: app opens on another', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final full = (await tester.runAsync(Resources.load))!;
    final cut = applyContentSelection(
      full.content,
      manifest({
        'app:ru:ruWords': {'enabled': false, 'excluded': []},
        'app:all:digits': {'enabled': false, 'excluded': []},
      }),
    );
    expect(cut.applied, true);
    final resources = Resources(
      cut.catalog,
      full.keyboards,
      full.registry,
      full.course,
      full.learning,
      full.kids,
    );
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction(
      (d) => (d['prefs'] as Map).addAll(<String, dynamic>{
        'pet': false,
        'profile': 'm',
        'lang': 'ru',
        'bank': 'ruWords',
        'textBank': 'ruWords',
      }),
    );
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(
      TypeFreeApp(
        key: key,
        resources: resources,
        repository: repo,
        initialSection: AppSection.practice,
        phone: false,
        appearance: AppearanceController(
          resources.registry,
          AppearanceMemory(),
          existingInstall: true,
        ),
      ),
    );
    await tester.pump();
    final app = key.currentState!;
    expect(app.bank, isNot('ruWords'));
    expect(app.exercises, isNotEmpty);
    expect(find.widgetWithText(CheckboxListTile, 'Только цифры'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

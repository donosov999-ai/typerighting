/// The author's release selection (private editor «Выгрузить курс для
/// приложения», format typefree-content-selection v1) applied to the practice
/// catalog. The app never reads the private editor: the manifest is shipped as
/// an asset and checked against the app's own catalog. Only practice banks are
/// covered (classic, poemHymn, ruWords, ruPhrases, digits); course, kids and
/// competition use other IDs and are reported as not applied. A manifest that
/// does not fit is rejected as a whole — the full catalog stays.
class SelectionResult {
  const SelectionResult(
    this.catalog, {
    this.applied = false,
    this.notes = const [],
  });
  final Map<String, dynamic> catalog;
  final bool applied;
  final List<String> notes;
}

const _practiceBanks = {
  'classic',
  'poemHymn',
  'ruWords',
  'ruPhrases',
  'digits',
};
const _lockedBanks = {'abandon', 'engRus', 'letterByLetter'};

SelectionResult applyContentSelection(
  Map<String, dynamic> catalog,
  Object? manifest,
) {
  // Locked banks must remain inaccessible even if a later catalog export
  // accidentally contains them or the selection manifest is missing/broken.
  final source = catalog['catalog'] as Map;
  final hasLocked = source.values.any(
    (rows) => (rows as List).any(
      (row) => _lockedBanks.contains((row as Map)['bank']),
    ),
  );
  if (hasLocked) {
    catalog = {
      ...catalog,
      'catalog': {
        for (final entry in source.entries)
          entry.key: [
            for (final row in entry.value as List)
              if (!_lockedBanks.contains((row as Map)['bank'])) row,
          ],
      },
    };
  }
  SelectionResult reject(String why) =>
      SelectionResult(catalog, notes: ['rejected: $why']);
  if (manifest == null) return SelectionResult(catalog);
  if (manifest is! Map ||
      manifest['format'] != 'typefree-content-selection' ||
      manifest['version'] != 1 ||
      manifest['groups'] is! Map) {
    return reject('format');
  }
  final items = <String, List<Map<String, dynamic>>>{
    for (final e in (catalog['catalog'] as Map).entries)
      e.key as String: [
        for (final i in e.value as List) Map<String, dynamic>.from(i as Map),
      ],
  };
  // Group id → entry ids it covers in this app.
  Set<String> idsOf(String language, String bank) => {
    for (final e in items.entries)
      if (language == 'all' || e.key == language)
        for (final i in e.value)
          if (i['bank'] == bank) i['id'] as String,
  };
  final drop = <String>{};
  final dropBank = <String>{}; // "<lang>|<bank>" or "all|digits"
  final notes = <String>[];
  for (final g in (manifest['groups'] as Map).entries) {
    final id = g.key, setting = g.value;
    if (id is! String ||
        setting is! Map ||
        setting['enabled'] is! bool ||
        setting['excluded'] is! List) {
      return reject('group $id');
    }
    final parts = id.split(':');
    if (parts.length != 3 || parts[0] != 'app') {
      notes.add('not applied: $id (not an app practice group)');
      continue;
    }
    final language = parts[1], bank = parts[2];
    if (_lockedBanks.contains(bank)) {
      if (setting['enabled'] == true) return reject('locked $id enabled');
      continue;
    }
    if (!_practiceBanks.contains(bank)) {
      notes.add('not applied: $id (course/kids/competition use other IDs)');
      continue;
    }
    final known = idsOf(language, bank);
    if (known.isEmpty) return reject('unknown group $id');
    final excluded = (setting['excluded'] as List).cast<Object?>();
    if (excluded.any((x) => x is! String || !known.contains(x))) {
      return reject('unknown entry in $id');
    }
    if (setting['enabled'] == false) {
      dropBank.add('$language|$bank');
    } else {
      drop.addAll(excluded.cast<String>());
    }
  }
  final out = <String, dynamic>{...catalog, 'catalog': <String, dynamic>{}};
  for (final e in items.entries) {
    final kept = [
      for (final i in e.value)
        if (!drop.contains(i['id']) &&
            !dropBank.contains('${e.key}|${i['bank']}') &&
            !dropBank.contains('all|${i['bank']}'))
          i,
    ];
    // Practice must stay possible in every language.
    if (kept.isEmpty) return reject('no practice left in ${e.key}');
    (out['catalog'] as Map)[e.key] = kept;
  }
  return SelectionResult(out, applied: true, notes: notes);
}

/// The bank to open: the saved one if the selection kept it, otherwise the
/// first bank that still has entries for this language.
String availableBank(
  Map<String, dynamic> catalog,
  String language,
  String bank,
) {
  final items = ((catalog['catalog'] as Map)[language] as List?) ?? const [];
  if (items.any((i) => (i as Map)['bank'] == bank)) return bank;
  return items.isEmpty ? bank : (items.first as Map)['bank'] as String;
}

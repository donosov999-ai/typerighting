import 'dart:convert';

/// Read models retain the limitations of legacy records: no invented language,
/// exercise, profile or mode, and no conversion of old rows into advisor facts.
class ProgressView {
  ProgressView(this.document);
  final Map<String, dynamic> document;
  List<Map<String, dynamic>> get sessions =>
      List<Map<String, dynamic>>.from(document['sessions'] as List);
  Map<String, dynamic> get archive => Map<String, dynamic>.from(
    (document['legacyArchive'] as Map?) ?? <String, dynamic>{},
  );

  List<Map<String, dynamic>> get previousSessions {
    final raw = archive['tr_history'];
    if (raw is! String) return [];
    final rows = jsonDecode(raw) as List;
    return [
      for (var i = 0; i < rows.length; i++)
        {
          ...Map<String, dynamic>.from(rows[i] as Map),
          'origin': 'legacy', 'id': 'legacy-$i',
          // Historical source accepts both 0..1 fractions and 0..100 percentages.
          // Raw values stay in the archive; the display matches source normalization.
          'accuracy': (rows[i]['acc'] as num) <= 1
              ? (rows[i]['acc'] as num) * 100
              : rows[i]['acc'],
        },
    ];
  }

  Map<String, dynamic> get legacy =>
      Map<String, dynamic>.from(document['legacy'] as Map);

  /// Old rows remain unlabelled; no profile or language is inferred.
  /// Every archived row is kept, duplicates included (they are separate old
  /// sessions). The mutable legacy mirror starts as a copy of the archive and
  /// then receives each Flutter session, so it is reduced as a multiset: first
  /// by the archived rows, then by rows matching a Flutter session. Only what
  /// remains (written by something else) is shown as an extra old row.
  List<Map<String, dynamic>> get legacyTimeline {
    List<Map<String, dynamic>> parse(Object? raw) => raw is String
        ? [
            for (final v in jsonDecode(raw) as List)
              Map<String, dynamic>.from(v as Map),
          ]
        : [];
    String signature(Map<String, dynamic> r) =>
        jsonEncode([r['t'], r['wpm'], r['acc'], r['len']]);
    final rows = parse(archive['tr_history']);
    final archived = <String, int>{};
    for (final r in rows) {
      archived.update(signature(r), (n) => n + 1, ifAbsent: () => 1);
    }
    final unmatched = [...sessions];
    for (final r in parse(legacy['tr_history'])) {
      final s = signature(r);
      if ((archived[s] ?? 0) > 0) {
        archived[s] = archived[s]! - 1;
        continue;
      }
      final i = unmatched.indexWhere(
        (f) =>
            f['t'] == r['t'] &&
            f['wpm'] == r['wpm'] &&
            (r['len'] == null || f['len'] == null || f['len'] == r['len']) &&
            (f['accuracy'] == r['acc'] ||
                f['accuracy'] == normalAccuracy(r['acc'] as num)),
      );
      if (i >= 0) {
        unmatched.removeAt(i);
        continue;
      }
      rows.add(r);
    }
    return [
      for (var i = 0; i < rows.length; i++)
        {
          ...rows[i],
          'origin': 'legacy',
          'id': 'legacy-$i',
          'accuracy': normalAccuracy(rows[i]['acc'] as num),
        },
    ];
  }

  List<Map<String, dynamic>> get timeline => [
    ...legacyTimeline,
    ...sessions.map((s) => {...s, 'origin': 'flutter'}),
  ]..sort((a, b) => (b['t'] as num).compareTo(a['t'] as num));

  Map<String, dynamic> get banks {
    final raw = document['legacy'] as Map;
    return {
      for (final e in raw.entries)
        if ((e.key as String).startsWith('tr_progress_'))
          (e.key as String).substring(12): jsonDecode(e.value as String),
    };
  }

  List<String> get achievements => {
    for (final raw in [archive['tr_ach'], legacy['tr_ach']])
      if (raw is String) ...List<String>.from(jsonDecode(raw) as List),
  }.toList();
  Map<String, int> _mergedStars(String key) {
    final stars = <String, int>{};
    for (final raw in [archive[key], legacy[key]]) {
      if (raw is! String) continue;
      for (final e in ((jsonDecode(raw) as Map)['stars'] as Map).entries) {
        final id = '${e.key}', value = e.value as int;
        if (value > (stars[id] ?? 0)) stars[id] = value;
      }
    }
    return stars;
  }

  int get courseStars => {...archive.keys, ...legacy.keys}
      .where((k) => k.startsWith('tr_course_'))
      .fold(
        0,
        (sum, key) => sum + _mergedStars(key).values.fold(0, (a, b) => a + b),
      );
  int get kidsStars => _mergedStars('tr_kids').values.fold(0, (a, b) => a + b);
}

num normalAccuracy(num value) => value <= 1 ? value * 100 : value;

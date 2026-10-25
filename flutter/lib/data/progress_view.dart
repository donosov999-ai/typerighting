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

  List<Map<String, dynamic>> get timeline => [
    ...previousSessions,
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

  List<String> get achievements => archive['tr_ach'] is String
      ? List<String>.from(jsonDecode(archive['tr_ach'] as String) as List)
      : [];
  int get courseStars => archive.entries
      .where((e) => e.key.startsWith('tr_course_'))
      .fold(0, (sum, e) => sum + _stars(e.value));
  int get kidsStars => _stars(archive['tr_kids']);
  int _stars(Object? raw) => raw is String
      ? ((jsonDecode(raw) as Map)['stars'] as Map).values.fold<int>(
          0,
          (s, v) => s + (v as int),
        )
      : 0;
}

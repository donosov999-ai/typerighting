import 'dart:convert';

class TodaySummary {
  TodaySummary(
    Map<String, dynamic> document, {
    required String profile,
    required String language,
    required DateTime now,
    required this.lessonCount,
  }) {
    final rows =
        List<Map<String, dynamic>>.from(document['sessions'] as List)
            .where((r) => r['profile'] == profile)
            .toList()
          ..sort((a, b) => (b['t'] as num).compareTo(a['t'] as num));
    latest = rows.isEmpty ? null : rows.first;
    // Old-version records have no profile: never a streak or latest result
    // here, only a hint that they exist (shown in «Прогресс»).
    final archived = ((document['legacyArchive'] as Map?) ??
        const {})['tr_history'];
    legacyCount = archived is String ? (jsonDecode(archived) as List).length : 0;
    final dates = rows.map((r) {
      final d = DateTime.fromMillisecondsSinceEpoch((r['t'] as num).toInt());
      return DateTime(d.year, d.month, d.day);
    }).toSet();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!dates.contains(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    while (dates.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    final raw = (document['legacy'] as Map)['tr_course_$language'];
    final stars = raw is String ? (jsonDecode(raw) as Map)['stars'] as Map : {};
    completed = List.generate(
      lessonCount,
      (i) => i + 1,
    ).where((id) => ((stars['$id'] as num?) ?? 0) > 0).length;
    nextLesson = List.generate(
      lessonCount,
      (i) => i + 1,
    ).firstWhere((id) => ((stars['$id'] as num?) ?? 0) == 0, orElse: () => 1);
    // A course can only open a lesson whose immediate predecessor was completed.
    if (nextLesson > 1 && ((stars['${nextLesson - 1}'] as num?) ?? 0) == 0) {
      nextLesson = 1;
    }
  }
  final int lessonCount;
  late final Map<String, dynamic>? latest;
  int streak = 0, completed = 0, nextLesson = 1, legacyCount = 0;
  double get progress => lessonCount == 0 ? 0 : completed / lessonCount;
}

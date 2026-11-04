import 'dart:convert';
import 'dart:math';

import '../domain/progress_metrics.dart';
import 'progress_view.dart';

/// Global device milestones match the legacy global scope. Unknown old metadata
/// does not become current-profile activity or evidence of a particular language.
List<String> eligibleAchievementIds(Map<String, dynamic> doc, int now) {
  final m = milestoneMetrics(doc, now);
  return unlockedMilestones(
    sessions: m['sessions']!.toInt(),
    streak: m['streak']!.toInt(),
    maxWpm: m['wpm']!,
    maxAccuracy: m['accuracy']!,
    languages: m['languages']!.toInt(),
  );
}

/// Current value of every milestone metric (progress toward locked badges).
Map<String, num> milestoneMetrics(Map<String, dynamic> doc, int now) {
  final view = ProgressView(doc);
  final rows = view.timeline
      .where((r) => r['historyEligible'] != false)
      .toList();
  final languages = <String>{};
  const supported = {'ru', 'en', 'es', 'de', 'fr', 'it', 'pt'};
  for (final row in rows) {
    if (supported.contains(row['language'])) {
      languages.add(row['language'] as String);
    }
  }
  for (final entry in view.legacy.entries) {
    if (!entry.key.startsWith('tr_course_')) continue;
    final language = entry.key.substring('tr_course_'.length);
    if (supported.contains(language) &&
        ((jsonDecode(entry.value as String) as Map)['stars'] as Map).values.any(
          (v) => (v as int) > 0,
        )) {
      languages.add(language);
    }
  }
  return {
    'sessions': rows.length,
    'streak': utcStreak(rows.map((r) => r['t'] as num), now),
    'wpm': rows.fold<num>(0, (n, r) => max(n, r['wpm'] as num)),
    'accuracy': rows.fold<num>(0, (n, r) => max(n, r['accuracy'] as num)),
    'languages': languages.length,
  };
}

/// Called inside the result transaction. Preserve imported/unknown badge IDs;
/// old source overwrites its list and can lose them after a capped history.
List<String> awardAchievements(Map<String, dynamic> doc, int now) {
  final before = ProgressView(doc).achievements.toSet();
  final eligible = eligibleAchievementIds(doc, now);
  final fresh = eligible.where((id) => !before.contains(id)).toList();
  if (fresh.isNotEmpty) {
    final combined = [...before, ...fresh];
    if (combined.length <= 1000) {
      (doc['legacy'] as Map)['tr_ach'] = jsonEncode(combined);
    } else {
      // The legacy field is limited to 1000 IDs. Preserve every old ID and
      // persist new known milestones separately rather than corrupting it.
      final prefs = doc['prefs'] as Map;
      prefs['flutterAchievements'] = {
        ...List<String>.from(prefs['flutterAchievements'] ?? []),
        ...fresh,
      }.toList();
    }
  }
  return fresh;
}

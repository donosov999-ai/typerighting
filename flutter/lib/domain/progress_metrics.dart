import 'dart:math';

class SpeedForecast {
  const SpeedForecast(this.sessions, this.certainty, this.target);
  final int sessions;
  final double certainty;
  final num target;
  Map<String, dynamic> toJson() => {
    'sessions': sessions,
    'certainty': certainty,
    'target': target,
  };
}

/// Shipped linear regression, last30 ordered sessions. Callers must choose a
/// comparable series; a mixed-mode WPM trend does not measure skill improvement.
SpeedForecast? speedForecast(List<num> orderedWpm, num target) {
  final ys = orderedWpm.skip(max(0, orderedWpm.length - 30)).toList(),
      n = min(30, orderedWpm.length);
  if (!target.isFinite || target <= 0 || n < 5 || ys.last >= target)
    return null;
  num sx = 0, sy = 0, sxx = 0, sxy = 0;
  for (var i = 0; i < n; i++) {
    sx += i;
    sy += ys[i];
    sxx += i * i;
    sxy += i * ys[i];
  }
  final denom = n * sxx - sx * sx;
  if (denom == 0) return null;
  final slope = (n * sxy - sx * sy) / denom, intercept = (sy - slope * sx) / n;
  if (slope <= .05) return null;
  final mean = sy / n;
  num total = 0, residual = 0;
  for (var i = 0; i < n; i++) {
    total += pow(ys[i] - mean, 2);
    residual += pow(ys[i] - (intercept + slope * i), 2);
  }
  final r2 = total > 0 ? 1 - residual / total : 0;
  if (r2 < .35) return null;
  final sessions = ((target - intercept) / slope - (n - 1)).ceil();
  if (sessions <= 0 || sessions > 200) return null;
  return SpeedForecast(sessions, (r2 * 100).round() / 100, target);
}

/// The original stats store uses UTC day buckets, not a moving24h window.
int utcStreak(Iterable<num> timestamps, int now) {
  final days = timestamps.map((t) => (t / 86400000).floor()).toSet();
  var day = (now / 86400000).floor(), count = 0;
  if (!days.contains(day)) day--;
  while (days.contains(day)) {
    count++;
    day--;
  }
  return count;
}

/// Source BADGES (src/achievements.ts): one metric and the value it needs.
class Milestone {
  const Milestone(this.id, this.icon, this.metric, this.goal);
  final String id, icon;

  /// sessions · streak · wpm · accuracy · languages
  final String metric;
  final num goal;
}

const milestones = [
  Milestone('first', '🌱', 'sessions', 1),
  Milestone('sessions10', '📈', 'sessions', 10),
  Milestone('sessions50', '🏅', 'sessions', 50),
  Milestone('streak3', '🔥', 'streak', 3),
  Milestone('streak7', '🔥', 'streak', 7),
  Milestone('streak30', '💎', 'streak', 30),
  Milestone('wpm30', '⚡', 'wpm', 30),
  Milestone('wpm50', '🚀', 'wpm', 50),
  Milestone('wpm70', '👑', 'wpm', 70),
  Milestone('acc99', '🎯', 'accuracy', 99),
  Milestone('polyglot', '🌍', 'languages', 3),
];
List<String> unlockedMilestones({
  required int sessions,
  required int streak,
  required num maxWpm,
  required num maxAccuracy,
  required int languages,
}) {
  final value = {
    'sessions': sessions,
    'streak': streak,
    'wpm': maxWpm,
    'accuracy': maxAccuracy,
    'languages': languages,
  };
  return [
    for (final m in milestones)
      if (value[m.metric]! >= m.goal) m.id,
  ];
}

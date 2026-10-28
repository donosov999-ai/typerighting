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

class Milestone {
  const Milestone(this.id, this.icon);
  final String id, icon;
}

const milestones = [
  Milestone('first', '🌱'),
  Milestone('sessions10', '📈'),
  Milestone('sessions50', '🏅'),
  Milestone('streak3', '🔥'),
  Milestone('streak7', '🔥'),
  Milestone('streak30', '💎'),
  Milestone('wpm30', '⚡'),
  Milestone('wpm50', '🚀'),
  Milestone('wpm70', '👑'),
  Milestone('acc99', '🎯'),
  Milestone('polyglot', '🌍'),
];
List<String> unlockedMilestones({
  required int sessions,
  required int streak,
  required num maxWpm,
  required num maxAccuracy,
  required int languages,
}) {
  final enabled = [
    sessions >= 1,
    sessions >= 10,
    sessions >= 50,
    streak >= 3,
    streak >= 7,
    streak >= 30,
    maxWpm >= 30,
    maxWpm >= 50,
    maxWpm >= 70,
    maxAccuracy >= 99,
    languages >= 3,
  ];
  return [
    for (var i = 0; i < milestones.length; i++)
      if (enabled[i]) milestones[i].id,
  ];
}

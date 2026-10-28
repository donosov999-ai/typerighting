/// A comparable series requires explicit saved context. Legacy rows with missing
/// metadata stay visible in history but never become advisor/trend evidence.
String? sessionSeriesKey(Map<String, dynamic> row) {
  const fields = ['profile', 'language', 'mode', 'difficulty'];
  if (fields.any((k) => row[k] is! String || (row[k] as String).isEmpty) ||
      row['historyEligible'] == false)
    return null;
  return fields
      .map(
        (k) => (row[k] as String).length.toString() + ':' + (row[k] as String),
      )
      .join('|');
}

List<Map<String, dynamic>> comparableHistory(
  Map<String, dynamic> point,
  Iterable<Map<String, dynamic>> history,
) {
  final key = sessionSeriesKey(point), at = point['t'];
  if (key == null || at is! num) return [];
  final seen = <String>{};
  return history.where((row) {
    final id = row['id'], time = row['t'];
    return id is String &&
        id != point['id'] &&
        seen.add(id) &&
        time is num &&
        time < at &&
        sessionSeriesKey(row) == key;
  }).toList()..sort((a, b) => (a['t'] as num).compareTo(b['t'] as num));
}

String typefreeGameId(String mode) => 'typefree.$mode';

import 'dart:math';

/// Physical letter keys and their characters, stable keyboard order breaks
/// ties. [activeLayout]: the characters of the selected layout (QWERTZ z/y,
/// AZERTY a/q, ä ö ü é …) — for weak-key analysis and drills. Without it the
/// shipped TypeScript inventory (base Latin letters), which AI practice
/// generation must keep to stay identical to the released app.
List<Map<String, String>> letterInventory(
  Map<String, dynamic> keyboard,
  String language, {
  bool activeLayout = false,
}) {
  final pattern = activeLayout
      ? RegExp(r'^[A-Za-zÀ-ÿŒœÆæА-Яа-яЁё]$')
      : RegExp(r'^[A-Za-zА-Яа-яЁё]$');
  String? ch(Map g) =>
      (language == 'ru' ? g['ru'] : g[activeLayout ? 'en' : 'baseEn'])
          ?.toString();
  return [
    for (final g in keyboard['keys'] as List)
      if (pattern.hasMatch(ch(g as Map) ?? ''))
        {'id': g['id'] as String, 'ch': ch(g)!.toLowerCase()},
  ];
}

double speedReference(Map stats) {
  final times =
      stats.values
          .where((s) => s['t'] != null && ((s['nt'] as num?) ?? 0) >= 3)
          .map((s) => (s['t'] as num).toDouble())
          .toList()
        ..sort();
  return times.length < 3 ? 0 : times[times.length ~/ 2];
}

double weakness(Map s, double ref) {
  final n = ((s['ok'] as num?) ?? 0) + ((s['err'] as num?) ?? 0);
  final errors = n > 0 ? ((s['err'] as num?) ?? 0) / n : 0;
  final speed = ref > 0 && s['t'] != null && ((s['nt'] as num?) ?? 0) >= 3
      ? (((s['t'] as num) - ref) / ref).clamp(0, 1)
      : 0;
  return .6 * errors + .4 * speed;
}

List<String> weakLetters(
  Map stats,
  List<Map<String, String>> letters, {
  int count = 6,
}) {
  final ref = speedReference(stats);
  final scored = <({String ch, double weak, num n, int order})>[];
  for (var i = 0; i < letters.length; i++) {
    final s = (stats[letters[i]['id']] as Map?) ?? {};
    final n = ((s['ok'] as num?) ?? 0) + ((s['err'] as num?) ?? 0);
    final w = n >= 3 ? weakness(s, ref) : 0.0;
    if (w > 0) scored.add((ch: letters[i]['ch']!, weak: w, n: n, order: i));
  }
  scored.sort((a, b) {
    final w = b.weak.compareTo(a.weak);
    if (w != 0) return w;
    final n = b.n.compareTo(a.n);
    return n != 0 ? n : a.order.compareTo(b.order);
  });
  return scored.take(count).map((s) => s.ch).toList();
}

List<String> recoveryLetters(
  Map stats,
  List<Map<String, String>> letters, {
  int count = 3,
  double drop = .25,
}) {
  final scored = <({String ch, double regression, int order})>[];
  for (var i = 0; i < letters.length; i++) {
    final s = (stats[letters[i]['id']] as Map?) ?? {};
    final regression =
        s['bt'] != null &&
            (s['bt'] as num) > 0 &&
            s['t'] != null &&
            ((s['nt'] as num?) ?? 0) >= 3
        ? ((s['t'] as num) - (s['bt'] as num)) / (s['bt'] as num)
        : 0.0;
    if (regression > drop) {
      scored.add((ch: letters[i]['ch']!, regression: regression, order: i));
    }
  }
  scored.sort((a, b) {
    final n = b.regression.compareTo(a.regression);
    return n != 0 ? n : a.order.compareTo(b.order);
  });
  return scored.take(count).map((s) => s.ch).toList();
}

Map<String, double> letterWeights(
  Map stats,
  List<Map<String, String>> letters, {
  double boost = 6,
}) {
  final ref = speedReference(stats), out = <String, double>{};
  for (final letter in letters) {
    final s = (stats[letter['id']] as Map?) ?? {};
    if (((s['ok'] as num?) ?? 0) + ((s['err'] as num?) ?? 0) < 4) continue;
    final w = weakness(s, ref);
    if (w > 0) out[letter['ch']!] = 1 + w * boost;
  }
  return out;
}

class NgramModel {
  NgramModel(String text, String language, {this.order = 3}) {
    final letters = RegExp(language == 'ru' ? r'[а-яё]' : r'[a-zà-ÿœæ]');
    final clean = text
        .toLowerCase()
        .split('')
        .map((c) => letters.hasMatch(c) ? c : ' ')
        .join()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalized = '${' ' * (order - 1)}$clean ';
    final startsSet = <String>{}, alphabetSet = <String>{};
    for (var i = 0; i + order <= normalized.length; i++) {
      final prefix = normalized.substring(i, i + order - 1),
          next = normalized[i + order - 1];
      if (next != ' ') alphabetSet.add(next);
      final rec = table.putIfAbsent(prefix, () => {});
      rec[next] = (rec[next] ?? 0) + 1;
      if (prefix[0] == ' ' && prefix.trim().isNotEmpty) startsSet.add(prefix);
    }
    starts.addAll(startsSet);
    alphabet.addAll(alphabetSet.toList()..sort());
  }
  final int order;
  final table = <String, Map<String, int>>{};
  final starts = <String>[], alphabet = <String>[];
  String generate({
    required double Function() random,
    int chars = 48,
    int maxWord = 8,
    Map<String, double> weights = const {},
    List<String> force = const [],
  }) {
    if (starts.isEmpty) return '';
    final out = <String>[];
    var safety = 0;
    while (out.join(' ').length < chars && safety++ < 400) {
      var prefix = starts[(random() * starts.length).floor()], word = '';
      word = prefix.trim();
      var guard = 0;
      while (guard++ < maxWord * 2) {
        final rec = table[prefix];
        if (rec == null) break;
        var total = 0.0;
        for (final e in rec.entries) {
          total += e.value * (weights[e.key] ?? 1);
        }
        var r = random() * total;
        var next = rec.keys.last;
        for (final e in rec.entries) {
          r -= e.value * (weights[e.key] ?? 1);
          if (r <= 0) {
            next = e.key;
            break;
          }
        }
        if (next == ' ') break;
        word += next;
        final extended = prefix + next;
        prefix = extended.substring(extended.length - (order - 1));
        if (word.length >= maxWord) break;
      }
      if (word.length < 2) continue;
      if (force.isNotEmpty && !word.split('').any(force.contains)) continue;
      out.add(word);
    }
    return out.join(' ');
  }
}

List<String> weakDrill(
  String corpus,
  String language,
  Map stats,
  List<Map<String, String>> letters, {
  double Function()? random,
  int lines = 5,
}) {
  final rng = random ?? Random().nextDouble,
      model = NgramModel(corpus, language == 'ru' ? 'ru' : 'en');
  final weights = letterWeights(stats, letters, boost: 12),
      force = <String>{
        ...weakLetters(stats, letters, count: 4),
        ...recoveryLetters(stats, letters, count: 2),
      }.toList();
  final out = <String>[], top = weakLetters(stats, letters, count: 1);
  // A weak key may be absent from the selected corpus. Practise it directly
  // and avoid forcing the generator into repeated impossible attempts.
  if (model.starts.isEmpty) {
    return top.isEmpty ? [] : [List.filled(6, top.first).join(' ')];
  }
  final availableForce = force.where(model.alphabet.contains).toList();
  if (top.isNotEmpty && !model.alphabet.contains(top.first)) {
    out.add(List.filled(6, top.first).join(' '));
  } else if (top.isNotEmpty) {
    final word = model
        .generate(
          random: rng,
          chars: 6,
          weights: weights,
          maxWord: 6,
          force: [top.first],
        )
        .split(' ')
        .first;
    if (word.length >= 2) {
      out.add('$word $word $word');
    } else {
      // A character can be in the alphabet yet only occur in one-letter
      // words (or beyond the generator's word-length limit).
      out.add(List.filled(6, top.first).join(' '));
    }
  }
  for (var i = 0; i < lines; i++) {
    out.add(
      model.generate(
        random: rng,
        chars: 44,
        weights: weights,
        maxWord: 8,
        force: availableForce,
      ),
    );
  }
  final nonEmpty = out.where((s) => s.isNotEmpty).toList();
  if (nonEmpty.isEmpty && top.isNotEmpty) {
    return [List.filled(6, top.first).join(' ')];
  }
  return nonEmpty;
}

String adaptiveNoData(String language) =>
    const {
      'ru': 'Пока мало данных. Печатайте дальше: карта появится после достаточного числа нажатий.',
      'en': 'Not enough data yet. Keep typing; the map appears after enough key samples.',
      'es': 'Aún faltan datos. Sigue escribiendo; el mapa aparecerá con más pulsaciones.',
      'de': 'Noch zu wenige Daten. Tippe weiter; die Karte erscheint nach genügend Anschlägen.',
      'fr': 'Pas encore assez de données. Continuez à taper pour faire apparaître la carte.',
      'it': 'Non ci sono ancora abbastanza dati. Continua a digitare per visualizzare la mappa.',
      'pt': 'Ainda faltam dados. Continue digitando para visualizar o mapa.',
    }[language] ??
    'Not enough data yet.';

String adaptiveCopy(String language, String key) {
  const copy = {
    'generate': [
      'Сгенерировать упражнение',
      'Generate exercise',
      'Generar ejercicio',
      'Übung erzeugen',
      'Générer un exercice',
      'Genera esercizio',
      'Gerar exercício',
    ],
    'recovery': [
      'Стали медленнее своего рекорда',
      'Slower than your best',
      'Más lentas que tu récord',
      'Langsamer als deine Bestzeit',
      'Plus lentes que votre record',
      'Più lenti del tuo record',
      'Mais lentas que seu recorde',
    ],
    'original': [
      'Оригинал',
      'Original',
      'Original',
      'Original',
      'Original',
      'Originale',
      'Original',
    ],
    'plain': [
      'Без пунктуации',
      'No punctuation',
      'Sin puntuación',
      'Ohne Satzzeichen',
      'Sans ponctuation',
      'Senza punteggiatura',
      'Sem pontuação',
    ],
    'scope': [
      'Карта использует общую статистику клавиш этого устройства. Результаты ниже — последние сохранённые тренировки выбранного профиля и языка. Прочерк означает, что результата ещё нет.',
      'The map uses shared key statistics on this device. Results below are the latest saved sessions for this profile and language. A dash means no result yet.',
      'El mapa usa estadísticas de teclas compartidas del dispositivo. Abajo aparecen las últimas sesiones guardadas de este perfil e idioma. Un guion indica que aún no hay resultado.',
      'Die Karte nutzt die gemeinsame Tastenstatistik dieses Geräts. Unten stehen die letzten gespeicherten Übungen dieses Profils und dieser Sprache. Ein Strich bedeutet: noch kein Ergebnis.',
      'La carte utilise les statistiques de touches partagées de cet appareil. Les résultats sont les dernières séances enregistrées de ce profil et de cette langue. Un tiret signifie aucun résultat.',
      'La mappa usa le statistiche dei tasti condivise del dispositivo. Sotto trovi le ultime sessioni salvate per questo profilo e lingua. Un trattino indica nessun risultato.',
      'O mapa usa as estatísticas de teclas compartilhadas deste dispositivo. Abaixo estão as últimas sessões salvas deste perfil e idioma. Um traço indica que ainda não há resultado.',
    ],
  };
  const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  final index = languages.indexOf(language);
  return copy[key]?[index < 0 ? 1 : index] ?? key;
}
